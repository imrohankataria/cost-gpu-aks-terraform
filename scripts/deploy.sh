#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
TERRAFORM_DIR="$SCRIPT_DIR/../terraform"
K8S_DIR="$SCRIPT_DIR/../kubernetes/manifests"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}AKS GPU Cluster Deployment Script${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Function to print status
print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

# Check prerequisites
echo "Checking prerequisites..."

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    print_error "Azure CLI is not installed. Please install it from https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
fi
print_status "Azure CLI is installed"

# Check if Terraform is installed
if ! command -v terraform &> /dev/null; then
    print_error "Terraform is not installed. Please install it from https://www.terraform.io/downloads.html"
    exit 1
fi
print_status "Terraform is installed"

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed. Please install it from https://kubernetes.io/docs/tasks/tools/"
    exit 1
fi
print_status "kubectl is installed"

# Check Azure CLI login
echo ""
echo "Checking Azure login status..."
if ! az account show &> /dev/null; then
    print_warning "Not logged in to Azure. Initiating login..."
    az login
fi
print_status "Logged in to Azure"

# Get current subscription
SUBSCRIPTION_NAME=$(az account show --query name -o tsv)
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
echo ""
echo -e "Current subscription: ${YELLOW}${SUBSCRIPTION_NAME}${NC}"
echo -e "Subscription ID: ${YELLOW}${SUBSCRIPTION_ID}${NC}"
echo ""
read -p "Continue with this subscription? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Please select the correct subscription with: az account set --subscription <subscription-id>"
    exit 1
fi

# Check for terraform.tfvars
echo ""
if [ ! -f "$TERRAFORM_DIR/terraform.tfvars" ]; then
    print_warning "terraform.tfvars not found. Creating from example..."
    
    read -p "Enter resource group name (default: rg-aks-gpu-cluster): " RG_NAME
    RG_NAME=${RG_NAME:-rg-aks-gpu-cluster}
    
    read -p "Enter Azure region (default: eastus): " LOCATION
    LOCATION=${LOCATION:-eastus}
    
    read -p "Enter cluster name (default: aks-gpu-cluster): " CLUSTER_NAME
    CLUSTER_NAME=${CLUSTER_NAME:-aks-gpu-cluster}
    
    read -p "Enter monthly budget in USD (default: 5000): " BUDGET
    BUDGET=${BUDGET:-5000}
    
    read -p "Enter email for budget alerts (optional): " EMAIL
    
    cat > "$TERRAFORM_DIR/terraform.tfvars" <<EOF
resource_group_name = "$RG_NAME"
location           = "$LOCATION"
cluster_name       = "$CLUSTER_NAME"
environment        = "dev"
monthly_budget_amount = $BUDGET
EOF

    if [ ! -z "$EMAIL" ]; then
        echo "budget_alert_emails = [\"$EMAIL\"]" >> "$TERRAFORM_DIR/terraform.tfvars"
    fi
    
    print_status "Created terraform.tfvars"
fi

# Deploy with Terraform
echo ""
echo -e "${GREEN}Step 1: Deploying infrastructure with Terraform${NC}"
echo "=============================================="
cd "$TERRAFORM_DIR"

echo "Initializing Terraform..."
terraform init

echo ""
echo "Planning Terraform deployment..."
terraform plan -out=tfplan

echo ""
read -p "Review the plan above. Continue with deployment? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_warning "Deployment cancelled by user"
    exit 0
fi

echo ""
echo "Applying Terraform configuration..."
terraform apply tfplan
rm -f tfplan

print_status "Infrastructure deployed successfully"

# Get cluster credentials
echo ""
echo -e "${GREEN}Step 2: Configuring kubectl${NC}"
echo "=============================================="
RG_NAME=$(terraform output -raw resource_group_name)
CLUSTER_NAME=$(terraform output -raw cluster_name)

echo "Getting AKS credentials..."
az aks get-credentials --resource-group "$RG_NAME" --name "$CLUSTER_NAME" --overwrite-existing

print_status "kubectl configured"

# Deploy Kubernetes manifests
echo ""
echo -e "${GREEN}Step 3: Deploying Kubernetes components${NC}"
echo "=============================================="

echo "Deploying NVIDIA device plugin..."
kubectl apply -f "$K8S_DIR/nvidia-device-plugin.yaml"
print_status "NVIDIA device plugin deployed"

echo ""
echo "Creating monitoring namespace and deploying monitoring stack..."
kubectl apply -f "$K8S_DIR/prometheus.yaml"
kubectl apply -f "$K8S_DIR/gpu-exporter.yaml"
kubectl apply -f "$K8S_DIR/grafana.yaml"
kubectl apply -f "$K8S_DIR/alert-rules.yaml"
print_status "Monitoring stack deployed"

# Wait for GPU nodes
echo ""
echo "Waiting for GPU nodes to be ready..."
echo "(This may take 5-10 minutes for nodes to provision and join the cluster)"
for i in {1..60}; do
    GPU_NODES=$(kubectl get nodes -l gpu-type=nvidia --no-headers 2>/dev/null | wc -l)
    if [ "$GPU_NODES" -gt 0 ]; then
        print_status "GPU nodes are ready ($GPU_NODES nodes)"
        break
    fi
    echo -n "."
    sleep 10
done

if [ "$GPU_NODES" -eq 0 ]; then
    print_warning "No GPU nodes detected yet. They may still be provisioning."
    print_warning "Check status with: kubectl get nodes -l gpu-type=nvidia"
fi

# Wait for monitoring pods
echo ""
echo "Waiting for monitoring pods to be ready..."
kubectl wait --for=condition=ready pod -l app=prometheus -n monitoring --timeout=300s 2>/dev/null || print_warning "Prometheus pod not ready yet"
kubectl wait --for=condition=ready pod -l app=grafana -n monitoring --timeout=300s 2>/dev/null || print_warning "Grafana pod not ready yet"

# Get Grafana service details
echo ""
echo -e "${GREEN}Step 4: Getting access information${NC}"
echo "=============================================="

echo ""
echo "Waiting for Grafana LoadBalancer to get an external IP..."
for i in {1..30}; do
    GRAFANA_IP=$(kubectl get svc grafana -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
    if [ ! -z "$GRAFANA_IP" ]; then
        break
    fi
    echo -n "."
    sleep 10
done
echo ""

if [ ! -z "$GRAFANA_IP" ]; then
    print_status "Grafana is accessible at: http://$GRAFANA_IP:3000"
    echo "    Username: admin"
    echo "    Password: admin"
else
    print_warning "Grafana LoadBalancer IP not available yet"
    echo "    Get it later with: kubectl get svc grafana -n monitoring"
fi

# Display summary
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Deployment Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Cluster Information:"
echo "  Resource Group: $RG_NAME"
echo "  Cluster Name: $CLUSTER_NAME"
echo "  Region: $LOCATION"
echo ""
echo "Useful Commands:"
echo "  kubectl get nodes -l gpu-type=nvidia          # View GPU nodes"
echo "  kubectl get nodes -o wide                     # View all nodes"
echo "  kubectl apply -f kubernetes/manifests/example-workloads.yaml  # Deploy example GPU workload"
echo "  kubectl get pods -A                           # View all pods"
echo "  kubectl logs -n monitoring -l app=prometheus  # View Prometheus logs"
echo ""
echo "Cost Optimization Tips:"
echo "  - Spot instances are preferred for fault-tolerant workloads"
echo "  - Use node affinity to prefer spot nodes (see example-workloads.yaml)"
echo "  - Monitor GPU utilization in Grafana to optimize node counts"
echo "  - Check budget alerts in Azure portal"
echo ""
print_status "Setup complete!"
