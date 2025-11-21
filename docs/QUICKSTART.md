# Quick Start Guide

Get your AKS GPU cluster running in 5 minutes!

## Prerequisites Check

Before starting, ensure you have:
- ✅ Azure account with active subscription
- ✅ Azure CLI installed (`az --version`)
- ✅ Terraform installed (`terraform --version`)
- ✅ kubectl installed (`kubectl version --client`)
- ✅ Sufficient GPU quota in your Azure subscription

## Step-by-Step Deployment

### 1. Clone the Repository (30 seconds)

```bash
git clone https://github.com/imrohankataria/cost-gpu-aks-terraform.git
cd cost-gpu-aks-terraform
```

### 2. Login to Azure (1 minute)

```bash
az login
az account set --subscription "<your-subscription-id>"
```

### 3. Run the Deploy Script (3-8 minutes)

```bash
./scripts/deploy.sh
```

The script will:
- ✅ Validate all prerequisites
- ✅ Prompt for configuration (or use defaults)
- ✅ Deploy infrastructure with Terraform
- ✅ Configure kubectl
- ✅ Deploy monitoring stack
- ✅ Provide access information

### 4. Access Grafana Dashboard

After deployment completes, you'll see:

```
Grafana is accessible at: http://<EXTERNAL-IP>:3000
    Username: admin
    Password: admin
```

Visit the URL and explore the **GPU Cost & Health Dashboard**!

### 5. Deploy a Test GPU Workload (1 minute)

```bash
# Deploy example workload
kubectl apply -f kubernetes/manifests/example-workloads.yaml

# Check status
kubectl get pods

# View GPU allocation
kubectl describe pod gpu-workload-spot-example
```

## What You've Deployed

### Infrastructure
- ✅ AKS cluster with autoscaling system nodes
- ✅ Spot GPU node pool (0-10 nodes, 90% cost savings)
- ✅ On-Demand GPU node pool (1-5 nodes, high availability)
- ✅ Virtual network with Azure CNI
- ✅ Log Analytics workspace

### Monitoring
- ✅ Prometheus metrics collection
- ✅ NVIDIA DCGM GPU exporter
- ✅ Grafana dashboard with cost visualization
- ✅ Alert rules for GPU health

### Cost Management
- ✅ Budget alerts configured
- ✅ Resource tagging for cost tracking
- ✅ Autoscaling for cost optimization

## Configuration Options

### Quick Config

Edit `terraform/terraform.tfvars` before deployment:

```hcl
# Minimal configuration
resource_group_name = "my-gpu-cluster"
location           = "eastus"
cluster_name       = "my-aks-gpu"
monthly_budget_amount = 2000
budget_alert_emails   = ["me@example.com"]
```

### Advanced Config

```hcl
# Fine-tune GPU nodes
gpu_node_size          = "Standard_NC6s_v3"  # 1x V100
gpu_spot_min_count     = 0    # Scale to zero
gpu_spot_max_count     = 10   # Max spot nodes
gpu_ondemand_min_count = 1    # Always available
gpu_ondemand_max_count = 5    # Max on-demand
spot_max_price         = -1   # Market price
```

## Common First Tasks

### Check Cluster Health
```bash
kubectl get nodes -o wide
kubectl get pods -A
```

### View GPU Nodes
```bash
kubectl get nodes -l gpu-type=nvidia
```

### Check GPU Capacity
```bash
kubectl describe nodes -l gpu-type=nvidia | grep -A 5 "Capacity:"
```

### Run Cost Analysis
```bash
./scripts/cost-analysis.sh
```

### Scale GPU Nodes
```bash
# Scale spot nodes
az aks nodepool scale \
  --resource-group <rg-name> \
  --cluster-name <cluster-name> \
  --name gpuspot \
  --node-count 2
```

## Monitoring Your Cluster

### Grafana Dashboard
1. Access Grafana at the provided URL
2. Login with admin/admin
3. Navigate to **GPU Cost & Health Dashboard**
4. Monitor:
   - GPU utilization
   - GPU temperature
   - GPU memory usage
   - Node counts by type

### Prometheus Metrics
```bash
kubectl port-forward -n monitoring svc/prometheus 9090:9090
# Visit http://localhost:9090
```

### View Logs
```bash
# GPU exporter logs
kubectl logs -n monitoring -l app=nvidia-dcgm-exporter

# Prometheus logs
kubectl logs -n monitoring -l app=prometheus

# Grafana logs
kubectl logs -n monitoring -l app=grafana
```

## Cost Optimization Tips

### For Development
```hcl
gpu_spot_min_count = 0  # Scale to zero when idle
gpu_spot_max_count = 2  # Limit max nodes
```

### For Training
- Use spot nodes with checkpointing
- Schedule training during off-peak hours
- Monitor utilization to right-size nodes

### For Production Inference
- Use on-demand nodes for critical workloads
- Set appropriate min/max for autoscaling
- Implement health checks and monitoring

## Cleaning Up

When you're done:

```bash
./scripts/cleanup.sh
```

This will destroy all resources and clean up your environment.

## Next Steps

1. **Read the Documentation**
   - [Architecture Guide](docs/ARCHITECTURE.md)
   - [Cost Optimization Guide](docs/COST_OPTIMIZATION.md)
   - [Troubleshooting Guide](docs/TROUBLESHOOTING.md)

2. **Deploy Your Workloads**
   - Use example workloads as templates
   - Implement GPU scheduling preferences
   - Add checkpointing for spot instances

3. **Optimize Costs**
   - Monitor GPU utilization in Grafana
   - Adjust node pool sizes based on usage
   - Set up budget alerts

4. **Customize Monitoring**
   - Add custom Grafana dashboards
   - Create additional alert rules
   - Integrate with your alerting system

## Troubleshooting Quick Tips

### Deployment Fails
- Check Azure CLI login: `az account show`
- Verify quota: `az vm list-usage --location eastus -o table | grep NC`
- Review error message in Terraform output

### No GPU Nodes
- Wait 5-10 minutes for nodes to provision
- Check node pool status: `az aks nodepool list --resource-group <rg> --cluster-name <cluster>`
- Manually scale if needed: `az aks nodepool scale`

### Cannot Access Grafana
- Check service: `kubectl get svc grafana -n monitoring`
- Use port-forward: `kubectl port-forward -n monitoring svc/grafana 3000:3000`
- Visit http://localhost:3000

## Support

- 📖 [Full Documentation](README.md)
- 🐛 [Report Issues](https://github.com/imrohankataria/cost-gpu-aks-terraform/issues)
- 💬 [Discussions](https://github.com/imrohankataria/cost-gpu-aks-terraform/discussions)

---

**🎉 Congratulations!** You now have a production-ready, cost-optimized AKS GPU cluster!
