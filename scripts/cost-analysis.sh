#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}AKS GPU Cluster Cost Analysis${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "kubectl is not installed. Please install it first."
    exit 1
fi

# Check if cluster is accessible
if ! kubectl cluster-info &> /dev/null; then
    echo "Cannot connect to cluster. Please configure kubectl."
    exit 1
fi

# Get node information
echo -e "${GREEN}Node Information:${NC}"
echo "=================================="
echo ""

TOTAL_NODES=$(kubectl get nodes --no-headers | wc -l)
GPU_NODES=$(kubectl get nodes -l gpu-type=nvidia --no-headers | wc -l)
SPOT_NODES=$(kubectl get nodes -l kubernetes.azure.com/scalesetpriority=spot --no-headers 2>/dev/null | wc -l || echo 0)
ONDEMAND_NODES=$(kubectl get nodes -l priority=on-demand --no-headers 2>/dev/null | wc -l || echo 0)

echo "Total Nodes: $TOTAL_NODES"
echo "GPU Nodes: $GPU_NODES"
echo "  - Spot Nodes: $SPOT_NODES"
echo "  - On-Demand Nodes: $ONDEMAND_NODES"
echo ""

# Get GPU allocation
echo -e "${GREEN}GPU Resource Allocation:${NC}"
echo "=================================="
echo ""

kubectl get nodes -l gpu-type=nvidia -o json | jq -r '
  .items[] |
  "Node: \(.metadata.name)\n" +
  "  Priority: \(.metadata.labels["kubernetes.azure.com/scalesetpriority"] // .metadata.labels.priority // "on-demand")\n" +
  "  GPUs Total: \(.status.capacity["nvidia.com/gpu"])\n" +
  "  GPUs Allocatable: \(.status.allocatable["nvidia.com/gpu"])\n"
' 2>/dev/null || echo "jq not installed - skipping detailed GPU info"

# Estimate costs
echo ""
echo -e "${GREEN}Estimated Monthly Costs:${NC}"
echo "=================================="
echo ""

# Note: These are approximate costs based on East US region
# Actual costs may vary by region and time

SPOT_HOURLY=0.31     # Approximate spot price for Standard_NC6s_v3
ONDEMAND_HOURLY=3.06 # On-demand price for Standard_NC6s_v3
HOURS_PER_MONTH=730

SPOT_MONTHLY=$(echo "$SPOT_NODES * $SPOT_HOURLY * $HOURS_PER_MONTH" | bc)
ONDEMAND_MONTHLY=$(echo "$ONDEMAND_NODES * $ONDEMAND_HOURLY * $HOURS_PER_MONTH" | bc)
TOTAL_MONTHLY=$(echo "$SPOT_MONTHLY + $ONDEMAND_MONTHLY" | bc)

printf "Spot Nodes (${SPOT_NODES}x): \$%.2f/month\n" $SPOT_MONTHLY
printf "On-Demand Nodes (${ONDEMAND_NODES}x): \$%.2f/month\n" $ONDEMAND_MONTHLY
printf "Total GPU Nodes: \$%.2f/month\n" $TOTAL_MONTHLY
echo ""
echo -e "${YELLOW}Note: These are estimates for Standard_NC6s_v3 in East US${NC}"
echo -e "${YELLOW}Actual costs may vary. Check Azure Cost Management for precise costs.${NC}"
echo ""

# Cost optimization recommendations
echo -e "${GREEN}Cost Optimization Recommendations:${NC}"
echo "=================================="
echo ""

if [ $ONDEMAND_NODES -gt 0 ] && [ $SPOT_NODES -eq 0 ]; then
    echo "💡 Consider using Spot nodes for non-critical workloads to save up to 90%"
fi

if [ $GPU_NODES -eq 0 ]; then
    echo "✅ No GPU nodes currently running - excellent cost optimization!"
fi

# Check GPU utilization if Prometheus is available
PROM_POD=$(kubectl get pods -n monitoring -l app=prometheus -o name 2>/dev/null | head -1)
if [ ! -z "$PROM_POD" ]; then
    echo ""
    echo "Checking GPU utilization (last 1 hour)..."
    
    # Port-forward to Prometheus (in background)
    kubectl port-forward -n monitoring "$PROM_POD" 9090:9090 &>/dev/null &
    PF_PID=$!
    sleep 2
    
    # Query average GPU utilization
    AVG_UTIL=$(curl -s 'http://localhost:9090/api/v1/query?query=avg(DCGM_FI_DEV_GPU_UTIL)' 2>/dev/null | jq -r '.data.result[0].value[1]' 2>/dev/null || echo "N/A")
    
    # Kill port-forward
    kill $PF_PID 2>/dev/null || true
    
    if [ "$AVG_UTIL" != "N/A" ] && [ ! -z "$AVG_UTIL" ]; then
        printf "Average GPU Utilization: %.1f%%\n" $AVG_UTIL
        
        # Provide recommendations based on utilization
        UTIL_INT=$(printf "%.0f" $AVG_UTIL)
        if [ $UTIL_INT -lt 30 ]; then
            echo "💡 GPU utilization is low. Consider scaling down nodes to save costs."
        elif [ $UTIL_INT -gt 80 ]; then
            echo "⚠️  GPU utilization is high. Consider scaling up for better performance."
        else
            echo "✅ GPU utilization looks optimal."
        fi
    fi
fi

echo ""
echo -e "${GREEN}Cost Tracking Commands:${NC}"
echo "=================================="
echo ""
echo "# View detailed costs in Azure Portal:"
echo "az consumption usage list --start-date $(date -d '30 days ago' +%Y-%m-%d) --end-date $(date +%Y-%m-%d)"
echo ""
echo "# Export cost data to CSV:"
echo "az consumption usage list --output table > costs.csv"
echo ""
