# Cost-Optimized AKS GPU Cluster with Terraform

[![Terraform](https://img.shields.io/badge/Terraform-1.0+-623CE4?logo=terraform)](https://www.terraform.io/)
[![Azure](https://img.shields.io/badge/Azure-AKS-0078D4?logo=microsoft-azure)](https://azure.microsoft.com/en-us/services/kubernetes-service/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.28+-326CE5?logo=kubernetes)](https://kubernetes.io/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

Deploy a fully automated AKS GPU cluster using Terraform, with **Spot + On-Demand nodes**, autoscaling, GPU health alerts, and cost-governance baked in. This repo shows exactly how to cut GPU spend by combining Azure Spot instances, node autoscaling, and GPU-aware scheduling.

## 🚀 Features

- **💰 Cost Optimization**
  - Spot instance support for up to 90% cost savings
  - Automatic scaling based on workload demand
  - Budget alerts and cost tracking
  - Resource tagging for cost attribution

- **🎯 GPU-Optimized**
  - NVIDIA device plugin for GPU scheduling
  - GPU health monitoring with DCGM exporter
  - Temperature, utilization, and memory tracking
  - Automated alerts for GPU issues

- **📊 Monitoring & Dashboards**
  - Pre-configured Prometheus for metrics collection
  - Live Grafana cost dashboard
  - GPU utilization and health metrics
  - Node-level resource tracking

- **🔧 Production-Ready**
  - High availability with system node pool
  - Azure CNI networking
  - Log Analytics integration
  - Azure Policy enabled

## 📋 Prerequisites

Before deploying, ensure you have:

- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) (v2.30.0+)
- [Terraform](https://www.terraform.io/downloads.html) (v1.0+)
- [kubectl](https://kubernetes.io/docs/tasks/tools/) (v1.28+)
- An active Azure subscription with sufficient quota for GPU VMs

## 🎬 Quick Start (1-Click Deploy)

```bash
# Clone the repository
git clone https://github.com/imrohankataria/cost-gpu-aks-terraform.git
cd cost-gpu-aks-terraform

# Run the deployment script
./scripts/deploy.sh
```

The script will:
1. ✅ Validate prerequisites
2. 🔐 Check Azure login status
3. 📝 Create terraform.tfvars (if needed)
4. 🏗️ Deploy infrastructure with Terraform
5. ⚙️ Configure kubectl
6. 📦 Deploy Kubernetes components
7. 📊 Set up monitoring stack

## 📐 Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Azure AKS Cluster                       │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────┐  ┌──────────────────────────────────┐    │
│  │   System    │  │      GPU Node Pools              │    │
│  │  Node Pool  │  ├──────────────────────────────────┤    │
│  │             │  │  Spot Nodes (Cost-Optimized)     │    │
│  │ • Autoscale │  │  • Priority: Spot                │    │
│  │ • 1-3 nodes │  │  • Autoscale: 0-10 nodes         │    │
│  └─────────────┘  │  • Tolerations for eviction      │    │
│                   │                                   │    │
│                   │  On-Demand Nodes (Reliable)      │    │
│                   │  • Priority: Regular             │    │
│                   │  • Autoscale: 1-5 nodes          │    │
│                   │  • High-priority workloads       │    │
│                   └──────────────────────────────────┘    │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐ │
│  │           Monitoring Stack (monitoring ns)           │ │
│  ├──────────────────────────────────────────────────────┤ │
│  │  • Prometheus (Metrics Collection)                   │ │
│  │  • Grafana (Cost Dashboard)                          │ │
│  │  • NVIDIA DCGM Exporter (GPU Metrics)               │ │
│  │  • Alert Rules (GPU Health)                          │ │
│  └──────────────────────────────────────────────────────┘ │
│                                                             │
└─────────────────────────────────────────────────────────────┘
         │                              │
         ▼                              ▼
┌──────────────────┐         ┌───────────────────────┐
│  Log Analytics   │         │   Budget Alerts       │
│    Workspace     │         │   (Cost Governance)   │
└──────────────────┘         └───────────────────────┘
```

## 🔧 Configuration

### Terraform Variables

Create a `terraform/terraform.tfvars` file or modify variables during deployment:

```hcl
resource_group_name = "rg-aks-gpu-cluster"
location           = "eastus"
cluster_name       = "aks-gpu-cluster"
environment        = "dev"

# GPU Node Configuration
gpu_node_size           = "Standard_NC6s_v3"  # 1 x NVIDIA V100
gpu_spot_min_count      = 0
gpu_spot_max_count      = 10
gpu_ondemand_min_count  = 1
gpu_ondemand_max_count  = 5

# Cost Governance
monthly_budget_amount = 5000
budget_alert_emails   = ["your-email@example.com"]

# Tags
tags = {
  Project     = "AKS-GPU-Cost-Optimization"
  Environment = "dev"
  CostCenter  = "engineering"
}
```

### Available GPU VM Sizes

| VM Size | GPU | vCPUs | Memory | Approx. Cost/hr |
|---------|-----|-------|--------|----------------|
| Standard_NC6s_v3 | 1x V100 (16GB) | 6 | 112 GB | $3.06 (Spot: ~$0.31) |
| Standard_NC12s_v3 | 2x V100 (32GB) | 12 | 224 GB | $6.12 (Spot: ~$0.61) |
| Standard_NC24s_v3 | 4x V100 (64GB) | 24 | 448 GB | $12.24 (Spot: ~$1.22) |

*Note: Spot prices vary by region and availability*

## 📊 Monitoring Dashboard

Access Grafana dashboard after deployment:

```bash
# Get Grafana URL
kubectl get svc grafana -n monitoring

# Default credentials
Username: admin
Password: admin
```

The dashboard includes:
- 📈 GPU Utilization trends
- 🌡️ GPU Temperature monitoring
- 💾 GPU Memory usage
- 📊 Node count by type (Spot vs On-Demand)
- 💰 Cost optimization insights

## 🎯 Scheduling GPU Workloads

### Prefer Spot Nodes (Cost-Optimized)

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: gpu-workload-spot
spec:
  restartPolicy: OnFailure
  tolerations:
  - key: kubernetes.azure.com/scalesetpriority
    operator: Equal
    value: spot
    effect: NoSchedule
  affinity:
    nodeAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        preference:
          matchExpressions:
          - key: kubernetes.azure.com/scalesetpriority
            operator: In
            values:
            - spot
  containers:
  - name: gpu-container
    image: nvidia/cuda:11.8.0-base-ubuntu22.04
    command: ["nvidia-smi"]
    resources:
      limits:
        nvidia.com/gpu: 1
```

### Require On-Demand Nodes (High-Priority)

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: gpu-workload-ondemand
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: priority
            operator: In
            values:
            - on-demand
  containers:
  - name: gpu-container
    image: nvidia/cuda:11.8.0-base-ubuntu22.04
    resources:
      limits:
        nvidia.com/gpu: 1
```

## 🚨 GPU Health Alerts

Pre-configured alerts include:

- **Critical Alerts**
  - GPU temperature > 85°C
  - GPU XID errors (hardware issues)
  - No GPU nodes available

- **Warning Alerts**
  - High GPU utilization (>95% for 10min)
  - GPU memory pressure (>90%)
  - Power throttling detected
  - Spot node eviction

- **Info Alerts**
  - Low GPU utilization (<20% for 30min) - cost optimization opportunity

## 💰 Cost Optimization Tips

1. **Use Spot Instances for Training**
   - Train ML models on spot nodes (up to 90% savings)
   - Implement checkpointing for fault tolerance
   - Use node affinity to prefer spot nodes

2. **Scale to Zero**
   - GPU spot nodes can scale to 0 when not in use
   - Set `gpu_spot_min_count = 0`

3. **Monitor Utilization**
   - Use Grafana dashboard to identify underutilized GPUs
   - Right-size your node pools based on actual usage

4. **Budget Alerts**
   - Configure budget alerts to prevent overspend
   - Set monthly budget in `monthly_budget_amount`

5. **Resource Tagging**
   - All resources are tagged for cost attribution
   - Use Azure Cost Management for detailed analysis

## 📝 Useful Commands

```bash
# View all nodes
kubectl get nodes -o wide

# View GPU nodes only
kubectl get nodes -l gpu-type=nvidia

# Check GPU node capacity
kubectl describe nodes -l gpu-type=nvidia | grep -A 5 "Capacity:"

# Deploy example workload
kubectl apply -f kubernetes/manifests/example-workloads.yaml

# View GPU metrics
kubectl logs -n monitoring -l app=nvidia-dcgm-exporter

# Check autoscaling status
kubectl get hpa -A

# View Prometheus metrics
kubectl port-forward -n monitoring svc/prometheus 9090:9090
# Then visit http://localhost:9090

# View all pods
kubectl get pods -A
```

## 🧹 Cleanup

To destroy all resources:

```bash
./scripts/cleanup.sh
```

This will:
- Destroy all Terraform-managed resources
- Clean up kubectl context
- Remove all data (this is irreversible!)

## 🔍 Troubleshooting

### GPU nodes not showing up
```bash
# Check node status
kubectl get nodes -l gpu-type=nvidia

# Check node pool status in Azure
az aks nodepool show --resource-group <rg-name> --cluster-name <cluster-name> --name gpuspot
```

### NVIDIA device plugin not working
```bash
# Check daemonset status
kubectl get daemonset nvidia-device-plugin-daemonset -n kube-system

# Check logs
kubectl logs -n kube-system -l name=nvidia-device-plugin-ds
```

### Spot nodes getting evicted frequently
- Increase `spot_max_price` to reduce eviction probability
- Use multiple regions for better spot availability
- Implement proper tolerations and checkpointing in workloads

### Grafana not accessible
```bash
# Check Grafana pod
kubectl get pods -n monitoring -l app=grafana

# Check service
kubectl get svc grafana -n monitoring

# Port-forward if LoadBalancer not available
kubectl port-forward -n monitoring svc/grafana 3000:3000
```

## 📚 Additional Resources

- [Azure AKS Documentation](https://docs.microsoft.com/en-us/azure/aks/)
- [Azure Spot VMs](https://docs.microsoft.com/en-us/azure/virtual-machines/spot-vms)
- [NVIDIA GPU Operator](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/overview.html)
- [Kubernetes GPU Scheduling](https://kubernetes.io/docs/tasks/manage-gpus/scheduling-gpus/)

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## ⚠️ Disclaimer

This configuration is designed for cost optimization and may not be suitable for all production workloads. Always test thoroughly and adjust based on your specific requirements.

---

**💡 Pro Tip:** Start with spot nodes for development and training workloads. Reserve on-demand nodes for production inference and critical workloads that require high availability.