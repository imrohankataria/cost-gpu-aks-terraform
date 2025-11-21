# Cost-Optimized GPU AKS Terraform

This repository contains Terraform configurations to deploy an Azure Kubernetes Service (AKS) cluster with GPU-enabled nodes, optimized for cost efficiency.

## Features

- **Parameterized Configuration**: Fully customizable through variables
- **GPU Node Pool**: Dedicated node pool with GPU-enabled VMs
- **Cost Optimization**: 
  - Autoscaling support (scale to zero)
  - Optional spot instances for GPU nodes
  - Node taints to prevent non-GPU workloads on GPU nodes
- **Observability**: Optional Log Analytics workspace integration
- **Security**: RBAC enabled, Azure Policy support
- **Flexible Networking**: Support for Azure CNI and Kubenet

## Prerequisites

- [Terraform](https://www.terraform.io/downloads.html) >= 1.0
- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) >= 2.0
- Azure subscription with appropriate permissions
- Service Principal or Managed Identity for Terraform

## Quick Start

1. **Clone the repository**
   ```bash
   git clone https://github.com/imrohankataria/cost-gpu-aks-terraform.git
   cd cost-gpu-aks-terraform
   ```

2. **Login to Azure**
   ```bash
   az login
   az account set --subscription <subscription-id>
   ```

3. **Configure variables**
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your desired configuration
   ```

4. **Initialize Terraform**
   ```bash
   terraform init
   ```

5. **Plan the deployment**
   ```bash
   terraform plan
   ```

6. **Apply the configuration**
   ```bash
   terraform apply
   ```

7. **Get AKS credentials**
   ```bash
   az aks get-credentials --resource-group <resource-group-name> --name <cluster-name>
   ```

## Configuration

### Available GPU VM Sizes

The following GPU-enabled VM sizes are commonly used for AKS:

- `Standard_NC4as_T4_v3` - 4 vCPUs, 28 GB RAM, 1x NVIDIA T4 (cost-effective)
- `Standard_NC6s_v3` - 6 vCPUs, 112 GB RAM, 1x NVIDIA V100
- `Standard_NC12s_v3` - 12 vCPUs, 224 GB RAM, 2x NVIDIA V100
- `Standard_ND40rs_v2` - 40 vCPUs, 672 GB RAM, 8x NVIDIA V100

### Key Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `resource_group_name` | Name of the resource group | `rg-aks-gpu` |
| `location` | Azure region | `eastus` |
| `cluster_name` | Name of the AKS cluster | `aks-gpu-cluster` |
| `gpu_node_vm_size` | VM size for GPU nodes | `Standard_NC4as_T4_v3` |
| `enable_auto_scaling` | Enable autoscaling for GPU nodes | `true` |
| `gpu_node_min_count` | Minimum GPU nodes (can be 0) | `0` |
| `gpu_node_max_count` | Maximum GPU nodes | `3` |
| `spot_instances_enabled` | Use spot instances for GPU nodes | `false` |

For a complete list of variables, see [variables.tf](variables.tf).

## Cost Optimization Strategies

1. **Autoscaling**: Enable `enable_auto_scaling = true` and set `gpu_node_min_count = 0` to scale down to zero when not in use.

2. **Spot Instances**: Set `spot_instances_enabled = true` to use Azure spot instances for up to 90% cost savings (with eviction risk).

3. **Right-sizing**: Choose the smallest GPU VM that meets your requirements (e.g., `Standard_NC4as_T4_v3` for T4 GPUs).

4. **Node Taints**: GPU nodes have taints by default to prevent non-GPU workloads from consuming expensive resources.

## Usage Examples

### Deploy with Spot Instances

```hcl
spot_instances_enabled = true
spot_max_price         = -1  # Pay up to on-demand price
```

### Scale to Zero Configuration

```hcl
enable_auto_scaling = true
gpu_node_min_count  = 0
gpu_node_max_count  = 5
```

### Deploy GPU Workload

When deploying workloads to GPU nodes, use tolerations:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: gpu-pod
spec:
  containers:
  - name: cuda-container
    image: nvidia/cuda:11.8.0-base-ubuntu22.04
    resources:
      limits:
        nvidia.com/gpu: 1
  tolerations:
  - key: "sku"
    operator: "Equal"
    value: "gpu"
    effect: "NoSchedule"
  nodeSelector:
    gpu-enabled: "true"
```

## Outputs

After deployment, the following outputs are available:

- `cluster_name`: Name of the AKS cluster
- `resource_group_name`: Name of the resource group
- `kube_config`: Kubernetes configuration (sensitive)
- `get_credentials_command`: Command to configure kubectl

View outputs:
```bash
terraform output
terraform output -raw kube_config > ~/.kube/config
```

## Clean Up

To destroy all resources:

```bash
terraform destroy
```

## Architecture

```
Azure Subscription
├── Resource Group
│   ├── AKS Cluster
│   │   ├── System Node Pool (Standard VMs)
│   │   └── GPU Node Pool (GPU VMs with autoscaling)
│   └── Log Analytics Workspace (optional)
```

## Security Considerations

- RBAC is enabled by default
- GPU nodes use taints to isolate GPU workloads
- Managed identity is used for cluster authentication
- Network policies can be enabled for pod-to-pod traffic control

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License.

## Support

For issues and questions, please open an issue in the GitHub repository.