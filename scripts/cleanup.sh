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

echo -e "${RED}========================================${NC}"
echo -e "${RED}AKS GPU Cluster Cleanup Script${NC}"
echo -e "${RED}========================================${NC}"
echo ""

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# Warning
echo -e "${RED}WARNING: This will destroy all resources created by Terraform!${NC}"
echo ""
echo "This includes:"
echo "  - AKS cluster and all workloads"
echo "  - Node pools (Spot and On-Demand)"
echo "  - Virtual network"
echo "  - Log Analytics workspace"
echo "  - All monitoring and data"
echo ""
read -p "Are you sure you want to continue? Type 'yes' to confirm: " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    print_warning "Cleanup cancelled"
    exit 0
fi

# Check if Terraform directory exists
if [ ! -d "$TERRAFORM_DIR" ]; then
    print_error "Terraform directory not found at $TERRAFORM_DIR"
    exit 1
fi

cd "$TERRAFORM_DIR"

# Check if Terraform is initialized
if [ ! -d ".terraform" ]; then
    print_warning "Terraform not initialized. Initializing now..."
    terraform init
fi

echo ""
echo "Planning destruction..."
terraform plan -destroy

echo ""
read -p "Review the destruction plan above. Proceed with cleanup? Type 'yes' to confirm: " CONFIRM2

if [ "$CONFIRM2" != "yes" ]; then
    print_warning "Cleanup cancelled"
    exit 0
fi

echo ""
echo "Destroying infrastructure..."
terraform destroy -auto-approve

print_status "All resources have been destroyed"

# Cleanup local kubeconfig context
echo ""
echo "Cleaning up kubectl context..."
CONTEXT_NAME=$(grep "cluster_name" terraform.tfvars 2>/dev/null | cut -d'"' -f2 || echo "")
if [ ! -z "$CONTEXT_NAME" ]; then
    kubectl config delete-context "$CONTEXT_NAME" 2>/dev/null || true
    print_status "Kubectl context cleaned up"
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Cleanup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
