# Frequently Asked Questions (FAQ)

## General Questions

### Q: What is this project?
**A:** This is a complete Infrastructure-as-Code solution for deploying cost-optimized GPU clusters on Azure Kubernetes Service (AKS). It combines spot instances, autoscaling, and comprehensive monitoring to reduce GPU costs by up to 90%.

### Q: Who is this for?
**A:** This solution is ideal for:
- ML/AI engineers running training workloads
- Data scientists needing GPU compute
- Companies looking to reduce cloud GPU costs
- DevOps teams managing GPU infrastructure
- Anyone running GPU workloads on Azure

### Q: How much can I save?
**A:** With spot instances, you can save up to 90% compared to on-demand pricing. For example:
- On-Demand GPU node: $3.06/hour ($2,234/month)
- Spot GPU node: $0.31/hour ($226/month)
- **Savings: $2,008/month per node (90%)**

## Deployment Questions

### Q: How long does deployment take?
**A:** Initial deployment typically takes 8-12 minutes:
- Terraform infrastructure: 5-8 minutes
- Kubernetes components: 2-3 minutes
- GPU nodes provisioning: 1-2 minutes

### Q: What are the Azure quota requirements?
**A:** You'll need quota for:
- **Standard_NC6s_v3** (or your chosen GPU VM size)
- Minimum: 6 vCPUs for GPU nodes
- Recommended: 30-60 vCPUs for full deployment

Check quota: `az vm list-usage --location eastus -o table | grep NC`

### Q: Which Azure regions support GPU VMs?
**A:** GPU VMs are available in many regions. Popular options:
- East US
- West US 2
- North Europe
- Southeast Asia

Check availability: `az vm list-skus --location eastus --size Standard_NC --all`

### Q: Can I deploy to multiple regions?
**A:** Yes, but each region requires a separate Terraform deployment. You can:
1. Duplicate the terraform directory
2. Update the region in variables
3. Deploy independently
4. Use Azure Traffic Manager for global routing

## Cost Questions

### Q: What costs will I incur?
**A:** Expected monthly costs:
- **System nodes**: ~$150
- **GPU spot nodes**: ~$226 per node (when running)
- **GPU on-demand nodes**: ~$2,234 per node
- **Log Analytics**: ~$2.30/GB ingested
- **Storage**: ~$5-20
- **Network egress**: Variable

**Typical total**: $500-3,000/month depending on usage

### Q: How do I minimize costs?
**A:** Best practices:
1. Use spot instances for non-critical workloads
2. Enable scale-to-zero for spot nodes (`gpu_spot_min_count = 0`)
3. Monitor GPU utilization and right-size
4. Use autoscaling aggressively
5. Schedule batch jobs during off-peak hours
6. Set budget alerts to prevent overspend

See [Cost Optimization Guide](COST_OPTIMIZATION.md) for details.

### Q: What if I exceed my budget?
**A:** The solution includes budget alerts at 80% and 100% thresholds. When exceeded:
1. Email alerts are sent to configured addresses
2. You can manually scale down nodes
3. Consider implementing Azure Policy to auto-stop resources
4. Review utilization to optimize configuration

### Q: Do spot nodes cost less than on-demand?
**A:** Yes! Spot instances typically cost 80-90% less than on-demand. However:
- Prices vary by region and time
- Nodes can be evicted with 30 seconds notice
- Best for fault-tolerant workloads
- Implement checkpointing for long-running jobs

## Technical Questions

### Q: What GPU types are supported?
**A:** The solution supports Azure NC-series VMs with NVIDIA GPUs:
- **Standard_NC6s_v3**: 1× Tesla V100 (16GB)
- **Standard_NC12s_v3**: 2× Tesla V100 (32GB)
- **Standard_NC24s_v3**: 4× Tesla V100 (64GB)
- **Standard_NC6s_v4**: 1× Tesla A100 (40GB)
- **Standard_NC24s_v4**: 4× Tesla A100 (160GB)

Change VM size in `terraform/terraform.tfvars`:
```hcl
gpu_node_size = "Standard_NC6s_v3"
```

### Q: Can I use different GPU types for spot vs on-demand?
**A:** Not directly in the current configuration, but you can:
1. Modify `terraform/main.tf`
2. Add `vm_size` parameter to each node pool
3. Deploy with different sizes

### Q: How does autoscaling work?
**A:** The cluster autoscaler:
1. Monitors pod resource requests
2. Scales up when pods are unschedulable
3. Scales down when nodes are underutilized (<50% for 10min)
4. Respects min/max node counts
5. Considers pod disruption budgets
6. Prefers spot nodes for cost optimization

### Q: What happens when a spot node is evicted?
**A:** When Azure evicts a spot node:
1. 30-second warning is issued
2. Pods on the node are terminated
3. Kubernetes reschedules pods to available nodes
4. If no nodes available, autoscaler provisions new nodes
5. Jobs with `restartPolicy: OnFailure` automatically retry

**Best practices:**
- Implement checkpointing
- Use tolerations for spot instances
- Set appropriate backoff limits

### Q: How do I schedule workloads on specific node types?
**A:** Use node affinity and tolerations:

**For Spot Nodes:**
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

**For On-Demand Nodes:**
```yaml
affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
      - matchExpressions:
        - key: priority
          operator: In
          values:
          - on-demand
```

## Monitoring Questions

### Q: How do I access Grafana?
**A:** After deployment:
```bash
# Get external IP
kubectl get svc grafana -n monitoring

# Or use port-forward
kubectl port-forward -n monitoring svc/grafana 3000:3000
```

Default credentials: `admin` / `admin`

### Q: What metrics are collected?
**A:** Key metrics include:
- **GPU Utilization**: Real-time usage percentage
- **GPU Temperature**: Celsius
- **GPU Memory**: Used vs Available
- **GPU Power**: Watts and throttling
- **Node Count**: By type (spot/on-demand)
- **XID Errors**: Hardware issues

### Q: How do I create custom alerts?
**A:** Edit `kubernetes/manifests/alert-rules.yaml`:
```yaml
- alert: MyCustomAlert
  expr: DCGM_FI_DEV_GPU_UTIL > 90
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "GPU utilization high"
```

Apply: `kubectl apply -f kubernetes/manifests/alert-rules.yaml`

### Q: Where are logs stored?
**A:** Logs are stored in:
- **Log Analytics Workspace**: 30 days (configurable)
- **Container Insights**: Real-time container logs
- **Prometheus**: Metrics (in-memory with optional persistent storage)

Access: Azure Portal → Log Analytics Workspace → Logs

## Operational Questions

### Q: How do I update the cluster?
**A:** For infrastructure changes:
```bash
cd terraform
# Edit terraform.tfvars or *.tf files
terraform plan
terraform apply
```

For Kubernetes components:
```bash
kubectl apply -f kubernetes/manifests/
```

### Q: How do I upgrade Kubernetes version?
**A:** Update in `terraform/terraform.tfvars`:
```hcl
kubernetes_version = "1.29.0"
```

Then:
```bash
cd terraform
terraform plan
terraform apply
```

**Note:** AKS upgrades are rolling and may take 30-60 minutes.

### Q: How do I scale nodes manually?
**A:** Using Azure CLI:
```bash
# Scale spot nodes
az aks nodepool scale \
  --resource-group <rg-name> \
  --cluster-name <cluster-name> \
  --name gpuspot \
  --node-count 3

# Scale on-demand nodes
az aks nodepool scale \
  --resource-group <rg-name> \
  --cluster-name <cluster-name> \
  --name gpuod \
  --node-count 2
```

### Q: How do I backup my cluster?
**A:** Backup strategies:
1. **Infrastructure**: Version control Terraform code
2. **Workloads**: Store manifests in Git
3. **Data**: Use Azure Backup for PVs
4. **State**: Terraform state in remote backend

For comprehensive backup, consider [Velero](https://velero.io/).

### Q: How do I restore a deleted cluster?
**A:** If infrastructure is destroyed:
```bash
cd terraform
terraform apply
./scripts/deploy.sh
# Redeploy workloads from source control
```

### Q: Can I use this in production?
**A:** Yes! The solution is production-ready with:
- ✅ High availability configuration
- ✅ Monitoring and alerting
- ✅ Cost governance
- ✅ Security best practices
- ✅ Autoscaling

**Recommendations for production:**
- Use remote Terraform backend
- Implement GitOps workflow
- Add backup solution (Velero)
- Configure Azure AD integration
- Enable private cluster endpoint
- Implement network policies

## Troubleshooting Questions

### Q: GPU nodes aren't showing up. What should I do?
**A:** Check these common issues:
1. **Quota**: Verify GPU VM quota
2. **Provisioning time**: Wait 5-10 minutes
3. **Node pool status**: `az aks nodepool list`
4. **Autoscaler**: Check if min count is 0

See [Troubleshooting Guide](TROUBLESHOOTING.md) for details.

### Q: Pods are stuck in Pending state. Why?
**A:** Common reasons:
1. No GPU nodes available
2. Missing tolerations for spot nodes
3. Resource requests exceed available capacity
4. Node taints not tolerated

Debug: `kubectl describe pod <pod-name>`

### Q: Grafana shows "No data". How do I fix this?
**A:** Check:
1. Prometheus is running: `kubectl get pods -n monitoring -l app=prometheus`
2. DCGM exporter is running: `kubectl get pods -n monitoring -l app=nvidia-dcgm-exporter`
3. GPU nodes exist: `kubectl get nodes -l gpu-type=nvidia`
4. Prometheus can scrape metrics: Check targets in Prometheus UI

### Q: Spot nodes are evicted too frequently. What can I do?
**A:** Options:
1. Increase spot max price: `spot_max_price = 1.0`
2. Try different regions with better spot availability
3. Increase on-demand node capacity
4. Implement better checkpointing
5. Use priority classes to control scheduling

## Security Questions

### Q: Is this solution secure?
**A:** Security features include:
- ✅ Azure CNI with network policies
- ✅ System-assigned managed identity
- ✅ Azure Policy enabled
- ✅ RBAC for service accounts
- ✅ SecurityContext for pods
- ✅ Private subnet for nodes

**Additional recommendations:**
- Enable Azure AD integration
- Use private cluster endpoint
- Implement Azure Firewall
- Enable disk encryption
- Use Azure Key Vault for secrets

### Q: How do I secure Grafana?
**A:** Recommended steps:
1. Change default password immediately
2. Enable HTTPS (configure ingress with TLS)
3. Implement Azure AD SSO
4. Restrict access with network policies
5. Use LoadBalancer with source IP restrictions

### Q: Can I use private endpoints?
**A:** Yes, modify `terraform/main.tf`:
```hcl
resource "azurerm_kubernetes_cluster" "aks" {
  # ... existing config
  private_cluster_enabled = true
}
```

**Note:** This requires additional networking configuration.

## Customization Questions

### Q: Can I add more node pools?
**A:** Yes! In `terraform/main.tf`, add:
```hcl
resource "azurerm_kubernetes_cluster_node_pool" "my_pool" {
  name                  = "mypool"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id
  vm_size               = "Standard_NC6s_v3"
  # ... other configuration
}
```

### Q: Can I use Windows node pools?
**A:** Yes, but Windows nodes don't support GPU workloads well. Better to:
- Keep Linux for GPU nodes
- Add Windows pools for other workloads
- Use separate node pools

### Q: How do I customize Grafana dashboards?
**A:** Options:
1. Edit `kubernetes/manifests/grafana.yaml` ConfigMap
2. Import dashboards via UI
3. Use Grafana provisioning
4. Store dashboards in ConfigMaps

### Q: Can I integrate with external monitoring?
**A:** Yes! Options:
1. **Azure Monitor**: Already integrated via Log Analytics
2. **Datadog**: Add Datadog agent
3. **Prometheus Operator**: Replace standalone Prometheus
4. **ELK Stack**: Add Filebeat for log shipping

## Migration Questions

### Q: Can I migrate from another cluster?
**A:** Yes, migration steps:
1. Deploy this solution
2. Back up workloads: `kubectl get all --all-namespaces -o yaml > backup.yaml`
3. Export PVs data
4. Deploy workloads to new cluster
5. Validate and switch traffic
6. Decommission old cluster

### Q: Can I import existing AKS cluster?
**A:** Not directly, but you can:
1. Document existing configuration
2. Create equivalent Terraform code
3. Import state: `terraform import`
4. Validate: `terraform plan`

## Support Questions

### Q: Where can I get help?
**A:** Multiple support channels:
- 📖 [Documentation](README.md)
- 🐛 [GitHub Issues](https://github.com/imrohankataria/cost-gpu-aks-terraform/issues)
- 💬 [Discussions](https://github.com/imrohankataria/cost-gpu-aks-terraform/discussions)
- 📧 Email: Check repository owner

### Q: How do I report a bug?
**A:** Please open a GitHub issue with:
1. Clear description of the problem
2. Steps to reproduce
3. Expected vs actual behavior
4. Environment details (region, VM sizes, etc.)
5. Relevant logs or error messages

### Q: Can I contribute?
**A:** Absolutely! Contributions welcome:
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request
5. Describe your changes clearly

See [CONTRIBUTING.md](../CONTRIBUTING.md) for guidelines.

### Q: Is there a community?
**A:** Join the discussion:
- GitHub Discussions for Q&A
- Issues for bug reports
- Pull Requests for contributions

---

**Don't see your question?** Open a [GitHub Discussion](https://github.com/imrohankataria/cost-gpu-aks-terraform/discussions) or [Issue](https://github.com/imrohankataria/cost-gpu-aks-terraform/issues)!
