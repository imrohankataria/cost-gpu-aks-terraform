# GPU Workload Examples

This directory contains example Kubernetes manifests for deploying GPU workloads on your AKS cluster.

## Prerequisites

1. Deploy the AKS cluster using the Terraform configuration in the root directory
2. Get cluster credentials:
   ```bash
   az aks get-credentials --resource-group <resource-group-name> --name <cluster-name>
   ```
3. Install the NVIDIA GPU device plugin (if not already installed):
   ```bash
   kubectl apply -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/v0.14.0/nvidia-device-plugin.yml
   ```

## Examples

### GPU Test Pod

A simple pod to test GPU availability:

```bash
kubectl apply -f gpu-test-pod.yaml
kubectl logs gpu-test-pod
```

This will show `nvidia-smi` output confirming GPU access.

### GPU Deployment

A deployment that continuously runs on GPU nodes:

```bash
kubectl apply -f gpu-deployment.yaml
kubectl get pods -l app=gpu-workload
kubectl logs -f deployment/gpu-workload
```

## Important Notes

### Node Taints and Tolerations

All GPU nodes have the taint `sku=gpu:NoSchedule` to prevent non-GPU workloads from being scheduled on expensive GPU resources. Your GPU workloads must include the corresponding toleration:

```yaml
tolerations:
- key: "sku"
  operator: "Equal"
  value: "gpu"
  effect: "NoSchedule"
```

### Node Selector

To ensure your workload runs on GPU nodes, use the node selector:

```yaml
nodeSelector:
  gpu-enabled: "true"
```

### GPU Resource Requests

Request GPU resources in your container spec:

```yaml
resources:
  limits:
    nvidia.com/gpu: 1  # Number of GPUs
  requests:
    nvidia.com/gpu: 1
```

## Verify GPU Nodes

Check GPU nodes are available:

```bash
kubectl get nodes -l gpu-enabled=true
```

Check GPU resources:

```bash
kubectl describe node <gpu-node-name> | grep -A 5 "Allocated resources"
```

## Monitoring GPU Usage

View GPU metrics using nvidia-smi:

```bash
kubectl exec -it <pod-name> -- nvidia-smi
```

## Autoscaling Behavior

If autoscaling is enabled (default):
- GPU nodes scale to 0 when no GPU workloads are running
- New GPU nodes are provisioned when GPU workloads are scheduled
- Scaling typically takes 2-5 minutes

## Troubleshooting

If pods are not scheduling on GPU nodes:

1. Check node availability:
   ```bash
   kubectl get nodes -l gpu-enabled=true
   ```

2. Check pod events:
   ```bash
   kubectl describe pod <pod-name>
   ```

3. Verify tolerations and node selectors are correct

4. Check if GPU device plugin is running:
   ```bash
   kubectl get pods -n kube-system | grep nvidia
   ```
