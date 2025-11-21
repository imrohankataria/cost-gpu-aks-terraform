# Troubleshooting Guide

## Common Issues and Solutions

### 1. Terraform Deployment Issues

#### Issue: Azure CLI Not Logged In
**Symptom:**
```
Error: building AzureRM Client: obtain subscription() from Azure CLI...
```

**Solution:**
```bash
az login
az account set --subscription <subscription-id>
```

#### Issue: Insufficient Quota for GPU VMs
**Symptom:**
```
Error: creating Node Pool: Code="QuotaExceeded"
```

**Solution:**
```bash
# Check current quota
az vm list-usage --location eastus -o table | grep NC

# Request quota increase
# Go to Azure Portal > Subscriptions > Usage + quotas
# Filter for "Standard NCv3 Family vCPUs"
# Request increase
```

#### Issue: Terraform State Lock
**Symptom:**
```
Error: Error acquiring the state lock
```

**Solution:**
```bash
# Force unlock (use with caution)
terraform force-unlock <lock-id>
```

### 2. Kubernetes Cluster Access Issues

#### Issue: Cannot Get Cluster Credentials
**Symptom:**
```
Error: getting credentials for AKS Cluster
```

**Solution:**
```bash
# Re-authenticate to Azure
az login

# Get credentials with admin rights
az aks get-credentials \
  --resource-group <rg-name> \
  --name <cluster-name> \
  --admin \
  --overwrite-existing
```

#### Issue: kubectl Commands Timeout
**Symptom:**
```
Unable to connect to the server: dial tcp: i/o timeout
```

**Solution:**
```bash
# Check cluster status
az aks show --resource-group <rg-name> --name <cluster-name>

# Verify network connectivity
curl -v https://<cluster-fqdn>

# Check if VPN/firewall is blocking
```

### 3. GPU Node Issues

#### Issue: GPU Nodes Not Appearing
**Symptom:**
```
$ kubectl get nodes -l gpu-type=nvidia
No resources found
```

**Solution:**
```bash
# Check node pool status
az aks nodepool list \
  --resource-group <rg-name> \
  --cluster-name <cluster-name> \
  -o table

# Check autoscaler events
kubectl get events -A | grep -i scale

# Manually scale node pool
az aks nodepool scale \
  --resource-group <rg-name> \
  --cluster-name <cluster-name> \
  --name gpuspot \
  --node-count 1
```

#### Issue: NVIDIA Device Plugin Not Running
**Symptom:**
```
$ kubectl get daemonset -n kube-system nvidia-device-plugin-daemonset
nvidia-device-plugin-daemonset   0         0         0       0            0
```

**Solution:**
```bash
# Check if GPU nodes exist
kubectl get nodes -l gpu-type=nvidia

# Check pod status
kubectl get pods -n kube-system -l name=nvidia-device-plugin-ds

# Check logs
kubectl logs -n kube-system -l name=nvidia-device-plugin-ds

# Redeploy plugin
kubectl delete -f kubernetes/manifests/nvidia-device-plugin.yaml
kubectl apply -f kubernetes/manifests/nvidia-device-plugin.yaml
```

#### Issue: Pods Not Scheduled on GPU Nodes
**Symptom:**
```
$ kubectl get pods
NAME              STATUS    RESTARTS   AGE
gpu-workload      Pending   0          5m
```

**Solution:**
```bash
# Check why pod is pending
kubectl describe pod gpu-workload

# Common causes:
# 1. No GPU nodes available
kubectl get nodes -l gpu-type=nvidia

# 2. Missing tolerations for spot nodes
kubectl get pod gpu-workload -o yaml | grep -A 5 tolerations

# 3. Resource request too high
kubectl describe nodes -l gpu-type=nvidia | grep -A 5 "Allocated resources"
```

### 4. Spot Node Issues

#### Issue: Spot Nodes Frequently Evicted
**Symptom:** Nodes disappear and workloads restart frequently

**Solution:**
```bash
# Check eviction rate
kubectl get events -A | grep -i evict

# Options:
# 1. Increase spot max price
# Edit terraform/terraform.tfvars:
spot_max_price = 1.0  # Set specific max price

# 2. Use multiple regions
# 3. Increase on-demand node capacity
gpu_ondemand_min_count = 2
```

#### Issue: Workloads Not Tolerating Spot Nodes
**Symptom:** Pods scheduled only on on-demand nodes

**Solution:**
Add toleration to pod spec:
```yaml
tolerations:
- key: kubernetes.azure.com/scalesetpriority
  operator: Equal
  value: spot
  effect: NoSchedule
```

### 5. Monitoring Issues

#### Issue: Prometheus Not Scraping Metrics
**Symptom:** No metrics in Grafana dashboard

**Solution:**
```bash
# Check Prometheus pod
kubectl get pods -n monitoring -l app=prometheus

# Check Prometheus targets
kubectl port-forward -n monitoring svc/prometheus 9090:9090
# Visit http://localhost:9090/targets

# Check DCGM exporter
kubectl get pods -n monitoring -l app=nvidia-dcgm-exporter
kubectl logs -n monitoring -l app=nvidia-dcgm-exporter

# Verify GPU nodes have metrics endpoint
kubectl get pods -n monitoring -l app=nvidia-dcgm-exporter -o wide
```

#### Issue: Grafana Dashboard Empty
**Symptom:** Dashboard shows "No data"

**Solution:**
```bash
# Check if Prometheus datasource is configured
kubectl port-forward -n monitoring svc/grafana 3000:3000
# Visit http://localhost:3000
# Login (admin/admin)
# Configuration > Data Sources > Prometheus
# Test connection

# Check if metrics exist
kubectl port-forward -n monitoring svc/prometheus 9090:9090
# Visit http://localhost:9090
# Query: DCGM_FI_DEV_GPU_UTIL

# If no metrics, check GPU exporter
kubectl get daemonset -n monitoring nvidia-dcgm-exporter
```

#### Issue: Cannot Access Grafana LoadBalancer
**Symptom:** LoadBalancer IP not assigned

**Solution:**
```bash
# Check service status
kubectl get svc grafana -n monitoring

# Wait for IP assignment (can take 2-5 minutes)
kubectl get svc grafana -n monitoring --watch

# Alternative: Use port-forward
kubectl port-forward -n monitoring svc/grafana 3000:3000

# Check Azure Load Balancer
az network lb list --resource-group MC_<rg-name>_<cluster-name>_<location>
```

### 6. Cost and Budget Issues

#### Issue: Budget Alerts Not Received
**Symptom:** No email alerts despite exceeding threshold

**Solution:**
```bash
# Verify budget configuration
az consumption budget show \
  --resource-group <rg-name> \
  --budget-name <cluster-name>-budget

# Check email addresses
# Edit terraform/terraform.tfvars:
budget_alert_emails = ["correct-email@example.com"]

# Reapply Terraform
cd terraform
terraform apply
```

#### Issue: Unexpected High Costs
**Symptom:** Costs exceed expected amount

**Solution:**
```bash
# Check node count
kubectl get nodes -o wide

# Check node pool scaling
az aks nodepool show \
  --resource-group <rg-name> \
  --cluster-name <cluster-name> \
  --name gpuspot

# Review autoscaler status
kubectl get configmap cluster-autoscaler-status -n kube-system -o yaml

# Check for orphaned resources
az resource list --resource-group <rg-name>

# Review cost breakdown
./scripts/cost-analysis.sh
```

### 7. Autoscaling Issues

#### Issue: Nodes Not Scaling Down
**Symptom:** Idle nodes remain in cluster

**Solution:**
```bash
# Check autoscaler logs
kubectl logs -n kube-system -l app=cluster-autoscaler

# Common causes:
# 1. Pods without proper eviction settings
kubectl get pods -A -o yaml | grep -i "descheduler\|evict"

# 2. System pods on GPU nodes
kubectl get pods -A -o wide | grep <gpu-node-name>

# 3. PodDisruptionBudget preventing scale-down
kubectl get pdb -A

# Force scale-down (testing only)
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data
```

#### Issue: Nodes Not Scaling Up
**Symptom:** Pending pods but no new nodes

**Solution:**
```bash
# Check autoscaler events
kubectl get events -A | grep -i autoscaler

# Check node pool limits
az aks nodepool show \
  --resource-group <rg-name> \
  --cluster-name <cluster-name> \
  --name gpuspot \
  --query "count"

# Verify quota
az vm list-usage --location <location> -o table | grep NC

# Check for spot capacity issues (if using spot)
# Try on-demand nodes temporarily
```

### 8. Performance Issues

#### Issue: Slow GPU Performance
**Symptom:** GPU workloads slower than expected

**Solution:**
```bash
# Check GPU utilization
kubectl exec -it <gpu-pod> -- nvidia-smi

# Check for throttling
kubectl logs -n monitoring -l app=nvidia-dcgm-exporter | grep -i throttle

# Verify GPU temperature
kubectl port-forward -n monitoring svc/grafana 3000:3000
# Check GPU Temperature in dashboard

# Check node resources
kubectl describe node <gpu-node-name>

# Verify correct GPU model
kubectl get nodes -l gpu-type=nvidia -o yaml | grep -i "nvidia.com/gpu"
```

#### Issue: Network Bottleneck
**Symptom:** Slow data transfer to/from GPU pods

**Solution:**
```bash
# Check network policies
kubectl get networkpolicies -A

# Test network throughput
kubectl run network-test --image=networkstatic/iperf3 --rm -it -- iperf3 -s

# Check CNI plugin status
kubectl get pods -n kube-system | grep -i azure-cni

# Verify MTU settings
kubectl exec -it <pod-name> -- ip link show
```

## Diagnostic Commands

### Quick Health Check
```bash
#!/bin/bash
echo "=== Cluster Status ==="
kubectl cluster-info

echo -e "\n=== Node Status ==="
kubectl get nodes -o wide

echo -e "\n=== GPU Nodes ==="
kubectl get nodes -l gpu-type=nvidia

echo -e "\n=== GPU Capacity ==="
kubectl describe nodes -l gpu-type=nvidia | grep -A 5 "Capacity:"

echo -e "\n=== Monitoring Stack ==="
kubectl get pods -n monitoring

echo -e "\n=== Device Plugin ==="
kubectl get daemonset -n kube-system nvidia-device-plugin-daemonset

echo -e "\n=== Recent Events ==="
kubectl get events -A --sort-by='.lastTimestamp' | tail -20
```

### Cost Analysis
```bash
./scripts/cost-analysis.sh
```

### Full Diagnostic Report
```bash
#!/bin/bash
OUTPUT="diagnostic-report-$(date +%Y%m%d-%H%M%S).txt"

{
  echo "=== Diagnostic Report $(date) ==="
  echo ""
  
  echo "=== Cluster Info ==="
  kubectl cluster-info
  echo ""
  
  echo "=== All Nodes ==="
  kubectl get nodes -o wide
  echo ""
  
  echo "=== GPU Nodes Details ==="
  kubectl describe nodes -l gpu-type=nvidia
  echo ""
  
  echo "=== All Pods ==="
  kubectl get pods -A -o wide
  echo ""
  
  echo "=== Monitoring Pods ==="
  kubectl get pods -n monitoring
  echo ""
  
  echo "=== Recent Events ==="
  kubectl get events -A --sort-by='.lastTimestamp' | tail -50
  echo ""
  
  echo "=== Node Pool Status ==="
  az aks nodepool list --resource-group <rg-name> --cluster-name <cluster-name>
  echo ""
  
  echo "=== Budget Status ==="
  az consumption budget list --resource-group <rg-name>
  
} > "$OUTPUT"

echo "Report saved to $OUTPUT"
```

## Getting Help

If you're still experiencing issues:

1. **Check Logs:**
   ```bash
   # Cluster autoscaler
   kubectl logs -n kube-system -l app=cluster-autoscaler
   
   # GPU plugin
   kubectl logs -n kube-system -l name=nvidia-device-plugin-ds
   
   # Monitoring
   kubectl logs -n monitoring -l app=prometheus
   ```

2. **Review Azure Activity Log:**
   - Go to Azure Portal > Resource Group > Activity Log
   - Filter by failed operations

3. **Check Azure Service Health:**
   - Azure Portal > Service Health
   - Check for outages in your region

4. **Community Resources:**
   - [AKS GitHub Issues](https://github.com/Azure/AKS/issues)
   - [NVIDIA GPU Operator Issues](https://github.com/NVIDIA/gpu-operator/issues)
   - [Stack Overflow - azure-aks](https://stackoverflow.com/questions/tagged/azure-aks)

5. **Azure Support:**
   - Open a support ticket in Azure Portal
   - Include diagnostic report
