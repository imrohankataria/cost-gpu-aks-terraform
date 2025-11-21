# Cost Optimization Guide

## Overview

This guide provides strategies and best practices for minimizing GPU cluster costs while maintaining performance and reliability.

## Cost Breakdown

### GPU Node Costs (East US, Standard_NC6s_v3)

| Type | Hourly Cost | Monthly Cost | Savings |
|------|-------------|--------------|---------|
| On-Demand | $3.06 | $2,234 | Baseline |
| Spot (avg) | $0.31 | $226 | 90% |

*Note: Spot prices vary by region and time*

### Additional Costs
- System nodes: ~$150/month
- Log Analytics: ~$2.30/GB ingested
- Storage: ~$5-20/month
- Network egress: Variable

## Optimization Strategies

### 1. Maximize Spot Usage

**Configure Workloads for Spot**
```yaml
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
```

**Implement Checkpointing**
- Save progress regularly
- Resume from checkpoint on eviction
- Use persistent volumes for state

**Set Appropriate Retry Logic**
- Automatic pod restart on eviction
- Exponential backoff for retries
- Maximum retry attempts

### 2. Aggressive Autoscaling

**Scale to Zero**
```hcl
gpu_spot_min_count = 0
gpu_spot_max_count = 10
```

Benefits:
- Zero cost when no workloads
- Rapid scale-up when needed
- Ideal for batch/training workloads

**Optimize Scale-Down Timing**
```yaml
# Add to cluster autoscaler config
--scale-down-delay-after-add=5m
--scale-down-unneeded-time=10m
```

### 3. Right-Size Your Nodes

**Match GPU to Workload**
| Workload Type | Recommended GPU | Cost/Hour |
|---------------|-----------------|-----------|
| Small models | Standard_NC6s_v3 (1x V100) | $0.31 spot |
| Medium models | Standard_NC12s_v3 (2x V100) | $0.61 spot |
| Large models | Standard_NC24s_v3 (4x V100) | $1.22 spot |

**Monitor Utilization**
```bash
# Check GPU utilization
kubectl top nodes
./scripts/cost-analysis.sh
```

### 4. Optimize Monitoring Costs

**Reduce Log Retention**
```hcl
log_retention_days = 7  # Instead of 30
```

**Sample Metrics**
```yaml
# In prometheus config
scrape_interval: 30s  # Instead of 15s
```

**Filter Unnecessary Logs**
- Exclude debug logs in production
- Focus on error and warning levels

### 5. Budget Management

**Set Conservative Budgets**
```hcl
monthly_budget_amount = 1000  # Start conservative
budget_alert_emails   = ["team@example.com"]
```

**Multiple Alert Thresholds**
- 50%: Informational
- 80%: Warning
- 100%: Critical
- 120%: Emergency shutdown trigger

### 6. Regional Optimization

**Choose Lower-Cost Regions**
| Region | Standard_NC6s_v3 On-Demand | Spot Savings |
|--------|---------------------------|--------------|
| East US | $3.06/hr | ~90% |
| West US 2 | $3.06/hr | ~90% |
| North Europe | €2.75/hr | ~90% |

*Check current spot pricing: `az vm list-skus --location eastus --size Standard_NC --output table`*

### 7. Workload Scheduling

**Batch Processing in Off-Hours**
```yaml
# CronJob for off-peak processing
apiVersion: batch/v1
kind: CronJob
metadata:
  name: gpu-batch-job
spec:
  schedule: "0 2 * * *"  # 2 AM daily
  jobTemplate:
    spec:
      template:
        spec:
          # ... GPU pod spec with spot preference
```

**Priority Classes**
```yaml
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: gpu-high-priority
value: 1000
globalDefault: false
---
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: gpu-low-priority
value: 100
globalDefault: false
```

### 8. GPU Sharing Strategies

**Time-Slicing** (Future Enhancement)
- Multiple workloads share single GPU
- Good for inference workloads
- Requires NVIDIA time-slicing plugin

**Multi-Instance GPU (MIG)** (A100 GPUs)
- Partition single GPU into multiple instances
- Better isolation than time-slicing
- Requires A100 or H100 GPUs

## Cost Monitoring

### Daily Checklist
```bash
# 1. Check node count
kubectl get nodes -l gpu-type=nvidia

# 2. Check GPU utilization
./scripts/cost-analysis.sh

# 3. Review Grafana dashboard
# Visit Grafana and check "GPU Cost & Health Dashboard"

# 4. Check Azure costs
az consumption usage list --start-date $(date -d '1 day ago' +%Y-%m-%d)
```

### Weekly Review
- Analyze utilization trends
- Adjust min/max node counts
- Review spot eviction rates
- Optimize workload scheduling

### Monthly Actions
- Review Azure Cost Management
- Compare against budget
- Analyze cost by tag
- Adjust budget if needed

## Cost Reduction Scenarios

### Scenario 1: Development/Testing
**Configuration:**
```hcl
gpu_spot_min_count = 0
gpu_spot_max_count = 2
gpu_ondemand_min_count = 0
gpu_ondemand_max_count = 1
```
**Expected Cost:** $200-500/month
**Use Case:** Intermittent GPU usage, can tolerate interruptions

### Scenario 2: ML Training
**Configuration:**
```hcl
gpu_spot_min_count = 0
gpu_spot_max_count = 10
gpu_ondemand_min_count = 1
gpu_ondemand_max_count = 2
```
**Expected Cost:** $500-2000/month
**Use Case:** Regular training jobs with checkpointing

### Scenario 3: Production Inference
**Configuration:**
```hcl
gpu_spot_min_count = 2
gpu_spot_max_count = 10
gpu_ondemand_min_count = 2
gpu_ondemand_max_count = 5
```
**Expected Cost:** $1500-4000/month
**Use Case:** High-availability inference with burst capacity

## Advanced Cost Optimization

### 1. Reserved Instances
For predictable on-demand usage:
- 1-year: 40% savings
- 3-year: 60% savings
- Purchase via Azure Portal

### 2. Azure Hybrid Benefit
If you have Windows Server licenses:
- Apply to Windows node pools
- Up to 40% additional savings
- Combine with spot for maximum savings

### 3. Committed Use Discounts
For consistent usage patterns:
- Commit to specific usage level
- Receive discounted rates
- Available for VMs and GPU resources

### 4. Multi-Tenancy
Share cluster across teams:
- Implement namespace quotas
- Use resource quotas
- Charge back via cost allocation tags

## Troubleshooting Cost Issues

### High Unexpected Costs
```bash
# Check for orphaned resources
az resource list --resource-group <rg-name>

# Check all node pools
az aks nodepool list --resource-group <rg-name> --cluster-name <cluster-name>

# Verify autoscaler is working
kubectl get configmap cluster-autoscaler-status -n kube-system -o yaml
```

### Spot Nodes Not Scaling Down
```bash
# Check for pods preventing scale-down
kubectl get pods --all-namespaces -o wide | grep gpuspot

# Check autoscaler logs
kubectl logs -n kube-system -l app=cluster-autoscaler
```

### Budget Alerts Not Working
```bash
# Verify budget configuration
az consumption budget list --resource-group <rg-name>

# Check alert rules
az monitor action-group list --resource-group <rg-name>
```

## ROI Calculation

### Cost Savings Example
**Before Optimization:**
- 5x On-Demand GPU nodes: $10,638/month

**After Optimization:**
- 0-10x Spot GPU nodes: $226-2,260/month (avg $500)
- 1x On-Demand GPU node: $2,234/month
- **Total: ~$2,734/month**
- **Savings: $7,904/month (74%)**

### Break-Even Analysis
- Setup time: 2-4 hours
- Ongoing management: 2-4 hours/month
- Savings: $7,904/month
- **ROI: Positive from month 1**

## Best Practices Summary

✅ **Do:**
- Use spot instances for training and batch jobs
- Implement checkpointing for long-running jobs
- Monitor GPU utilization regularly
- Set up budget alerts
- Use autoscaling with scale-to-zero
- Tag all resources for cost tracking

❌ **Don't:**
- Run stateless workloads on on-demand nodes
- Keep idle GPU nodes running
- Ignore utilization metrics
- Skip budget configuration
- Use oversized VMs for small workloads

## Additional Resources

- [Azure Spot VMs Documentation](https://docs.microsoft.com/en-us/azure/virtual-machines/spot-vms)
- [AKS Cost Optimization](https://docs.microsoft.com/en-us/azure/aks/best-practices-cost)
- [Azure Cost Management](https://azure.microsoft.com/en-us/services/cost-management/)
- [NVIDIA GPU Monitoring](https://docs.nvidia.com/datacenter/cloud-native/gpu-telemetry/dcgm-exporter.html)
