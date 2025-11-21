# Deployment Verification Checklist

Use this checklist to verify your deployment is working correctly.

## Pre-Deployment Checklist

- [ ] Azure CLI installed and logged in
- [ ] Terraform installed (v1.0+)
- [ ] kubectl installed (v1.28+)
- [ ] Azure subscription has sufficient GPU quota
- [ ] Review and customize `terraform/terraform.tfvars`
- [ ] Budget alert emails configured

## Terraform Deployment Verification

- [ ] Terraform init completed successfully
- [ ] Terraform plan shows expected resources
- [ ] Terraform apply completed without errors
- [ ] Resource group created in Azure Portal
- [ ] AKS cluster visible in Azure Portal
- [ ] Log Analytics workspace created
- [ ] Budget alert configured

### Commands to Verify
```bash
# Check resource group
az group show --name <rg-name>

# Check AKS cluster
az aks show --resource-group <rg-name> --name <cluster-name>

# Check node pools
az aks nodepool list --resource-group <rg-name> --cluster-name <cluster-name>

# Check budget
az consumption budget list --resource-group <rg-name>
```

## Kubernetes Access Verification

- [ ] kubectl configured successfully
- [ ] Can access cluster: `kubectl cluster-info`
- [ ] Cluster nodes are ready: `kubectl get nodes`
- [ ] System node pool is running
- [ ] All node pools are healthy

### Commands to Verify
```bash
# Check cluster access
kubectl cluster-info

# Check all nodes
kubectl get nodes -o wide

# Check system pods
kubectl get pods -n kube-system
```

## GPU Node Verification

- [ ] GPU nodes are provisioned (may take 5-10 minutes)
- [ ] GPU nodes show in `kubectl get nodes`
- [ ] GPU nodes have correct labels
- [ ] GPU nodes have correct taints (spot nodes)
- [ ] GPU capacity is detected

### Commands to Verify
```bash
# Check GPU nodes
kubectl get nodes -l gpu-type=nvidia

# Check GPU capacity
kubectl describe nodes -l gpu-type=nvidia | grep -A 5 "Capacity:"

# Verify labels
kubectl get nodes -l gpu-type=nvidia --show-labels

# Check taints (spot nodes should have taint)
kubectl describe nodes -l kubernetes.azure.com/scalesetpriority=spot | grep Taints
```

Expected output for GPU capacity:
```
Capacity:
  nvidia.com/gpu: 1
```

## NVIDIA Device Plugin Verification

- [ ] Device plugin DaemonSet is created
- [ ] Device plugin pods are running on GPU nodes
- [ ] No errors in device plugin logs

### Commands to Verify
```bash
# Check DaemonSet
kubectl get daemonset -n kube-system nvidia-device-plugin-daemonset

# Check pods
kubectl get pods -n kube-system -l name=nvidia-device-plugin-ds -o wide

# Check logs (should show GPU detected)
kubectl logs -n kube-system -l name=nvidia-device-plugin-ds --tail=50
```

Expected log output:
```
Loading NVML
Starting FS watcher
Starting OS watcher
```

## Monitoring Stack Verification

- [ ] Monitoring namespace created
- [ ] Prometheus pod is running
- [ ] NVIDIA DCGM exporter pods are running
- [ ] Grafana pod is running
- [ ] All monitoring pods are healthy

### Commands to Verify
```bash
# Check monitoring namespace
kubectl get namespace monitoring

# Check all monitoring pods
kubectl get pods -n monitoring

# Check Prometheus
kubectl get pods -n monitoring -l app=prometheus
kubectl logs -n monitoring -l app=prometheus --tail=50

# Check DCGM exporter
kubectl get daemonset -n monitoring nvidia-dcgm-exporter
kubectl get pods -n monitoring -l app=nvidia-dcgm-exporter -o wide

# Check Grafana
kubectl get pods -n monitoring -l app=grafana
```

All pods should be in `Running` state with `READY 1/1`.

## Grafana Dashboard Verification

- [ ] Grafana service has external IP
- [ ] Can access Grafana UI
- [ ] Can login with default credentials (admin/admin)
- [ ] Prometheus datasource is configured
- [ ] GPU Cost & Health Dashboard exists
- [ ] Dashboard shows data (may take 2-3 minutes)

### Commands to Verify
```bash
# Get Grafana external IP
kubectl get svc grafana -n monitoring

# Or use port-forward
kubectl port-forward -n monitoring svc/grafana 3000:3000
```

Access: `http://<EXTERNAL-IP>:3000` or `http://localhost:3000`

### Dashboard Checks
- [ ] GPU Utilization panel shows metrics
- [ ] GPU Temperature panel shows gauges
- [ ] GPU Memory Usage panel shows data
- [ ] Node Count panel shows correct counts

## Prometheus Metrics Verification

- [ ] Prometheus UI is accessible
- [ ] Can query GPU metrics
- [ ] Targets are being scraped successfully
- [ ] No scrape errors

### Commands to Verify
```bash
# Port-forward to Prometheus
kubectl port-forward -n monitoring svc/prometheus 9090:9090
```

Access: `http://localhost:9090`

### Metrics to Verify
Query these in Prometheus UI:
- [ ] `DCGM_FI_DEV_GPU_UTIL` - GPU utilization
- [ ] `DCGM_FI_DEV_GPU_TEMP` - GPU temperature
- [ ] `DCGM_FI_DEV_FB_USED` - GPU memory used
- [ ] `up{job="nvidia-dcgm"}` - Exporter health

## Alert Rules Verification

- [ ] Alert rules ConfigMap is created
- [ ] Prometheus has loaded alert rules
- [ ] Can see alerts in Prometheus UI

### Commands to Verify
```bash
# Check ConfigMap
kubectl get configmap prometheus-alerts -n monitoring

# Check if Prometheus loaded alerts (port-forward first)
# Visit http://localhost:9090/alerts
```

## Test Workload Verification

- [ ] Example workloads deployed successfully
- [ ] GPU workload pod is scheduled
- [ ] GPU is allocated to pod
- [ ] Pod can access GPU (nvidia-smi works)

### Commands to Verify
```bash
# Deploy example workload
kubectl apply -f kubernetes/manifests/example-workloads.yaml

# Check pod status
kubectl get pods

# Check GPU allocation
kubectl describe pod gpu-workload-spot-example | grep -A 5 "Limits:"

# Run nvidia-smi in pod (if it's running)
kubectl logs gpu-workload-spot-example
```

Expected output should show GPU information from nvidia-smi.

## Autoscaling Verification

- [ ] Cluster autoscaler is running
- [ ] Node pools have autoscaling enabled
- [ ] Min/Max node counts are correct

### Commands to Verify
```bash
# Check autoscaler pod
kubectl get pods -n kube-system -l app=cluster-autoscaler

# Check autoscaler status
kubectl get configmap cluster-autoscaler-status -n kube-system -o yaml

# Check node pool autoscaling settings
az aks nodepool show \
  --resource-group <rg-name> \
  --cluster-name <cluster-name> \
  --name gpuspot \
  --query "[minCount, maxCount, enableAutoScaling]"
```

## Cost Governance Verification

- [ ] Budget alerts are configured
- [ ] Can view budget in Azure Portal
- [ ] Resource tags are applied
- [ ] Log Analytics is collecting data

### Commands to Verify
```bash
# Check budget
az consumption budget show \
  --resource-group <rg-name> \
  --budget-name <cluster-name>-budget

# Check resource tags
az resource list --resource-group <rg-name> --query "[].tags"

# Run cost analysis script
./scripts/cost-analysis.sh
```

## Network Connectivity Verification

- [ ] Pods can reach internet (if needed)
- [ ] Pod-to-pod communication works
- [ ] Service discovery works
- [ ] LoadBalancer services get external IPs

### Commands to Verify
```bash
# Test pod-to-pod communication
kubectl run test-pod --image=busybox --rm -it -- ping <pod-ip>

# Test internet connectivity
kubectl run test-pod --image=busybox --rm -it -- ping 8.8.8.8

# Test DNS
kubectl run test-pod --image=busybox --rm -it -- nslookup kubernetes.default
```

## Security Verification

- [ ] RBAC is enabled
- [ ] Azure Policy is enabled
- [ ] Network policies can be applied
- [ ] Pods run with security contexts

### Commands to Verify
```bash
# Check RBAC
kubectl auth can-i list pods --as=system:serviceaccount:default:default

# Check Azure Policy
az aks show --resource-group <rg-name> --name <cluster-name> --query "azurePolicyEnabled"

# Check security contexts
kubectl get pod -n monitoring -o yaml | grep -A 5 securityContext
```

## Performance Verification

- [ ] GPU workload runs successfully
- [ ] GPU utilization is visible in monitoring
- [ ] No performance degradation
- [ ] Latency is acceptable

### Commands to Verify
```bash
# Run a simple GPU benchmark
kubectl run gpu-test --image=nvidia/cuda:11.8.0-base-ubuntu22.04 \
  --restart=Never --rm -it -- nvidia-smi

# Check GPU metrics in Grafana
# Should see utilization spike during workload
```

## Documentation Verification

- [ ] README is clear and accurate
- [ ] All documentation links work
- [ ] Examples are valid
- [ ] Troubleshooting guide is helpful

## Cleanup Verification

- [ ] Cleanup script runs without errors
- [ ] All resources are deleted
- [ ] Resource group is removed
- [ ] kubectl context is cleaned up

### Commands to Verify
```bash
# Run cleanup
./scripts/cleanup.sh

# Verify resource group is deleted
az group show --name <rg-name>
# Should return: ResourceGroupNotFound

# Verify kubectl context is removed
kubectl config get-contexts
# Your cluster context should be gone
```

## Post-Deployment Actions

- [ ] Change Grafana admin password
- [ ] Set up alerting (email, Slack, etc.)
- [ ] Configure backup strategy
- [ ] Document any customizations
- [ ] Set up monitoring alerts review schedule
- [ ] Share access with team members
- [ ] Create runbook for common operations

## Common Issues Checklist

If something doesn't work, check:

- [ ] Azure quota is sufficient
- [ ] Region supports GPU VMs
- [ ] Network connectivity is working
- [ ] Credentials are valid
- [ ] Kubernetes version is supported
- [ ] All prerequisites are met
- [ ] Waited sufficient time for provisioning
- [ ] Checked logs for errors

## Success Criteria

✅ **Minimum Success Criteria:**
- Cluster is accessible
- GPU nodes are provisioned
- Monitoring is working
- Can deploy GPU workloads

✅ **Full Success Criteria:**
- All items in checklist are completed
- Grafana dashboard shows data
- Alerts are configured
- Cost tracking is working
- Documentation is reviewed

## Support

If you encounter issues:
1. Review [Troubleshooting Guide](docs/TROUBLESHOOTING.md)
2. Check [FAQ](docs/FAQ.md)
3. Review deployment logs
4. Open a GitHub issue with details

---

**Deployment completed successfully?** 🎉 Time to optimize costs and run GPU workloads!
