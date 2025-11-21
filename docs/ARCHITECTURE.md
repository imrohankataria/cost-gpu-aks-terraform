# Architecture Overview

## High-Level Design

This solution implements a cost-optimized Azure Kubernetes Service (AKS) cluster specifically designed for GPU workloads. The architecture combines Azure Spot instances with on-demand nodes to provide a balance between cost savings and reliability.

## Components

### 1. Infrastructure Layer (Terraform)

#### Resource Group
- Contains all resources for the GPU cluster
- Tagged for cost tracking and attribution

#### Networking
- **Virtual Network**: Isolated network for the cluster
- **Subnet**: Dedicated subnet for AKS nodes
- **Azure CNI**: Advanced networking for pod-level IP addressing

#### AKS Cluster
- **Control Plane**: Managed by Azure
- **System Node Pool**: 
  - Runs critical system pods
  - Autoscales between 1-3 nodes
  - VM Size: Standard_D4s_v3

#### GPU Node Pools

**Spot Node Pool** (`gpuspot`):
- Priority: Spot
- Eviction Policy: Delete
- Min Nodes: 0 (can scale to zero)
- Max Nodes: 10
- Cost Savings: Up to 90% compared to on-demand

**On-Demand Node Pool** (`gpuod`):
- Priority: Regular
- Min Nodes: 1
- Max Nodes: 5
- Use Case: Critical workloads requiring high availability

### 2. Kubernetes Layer

#### GPU Device Plugin
- NVIDIA Device Plugin DaemonSet
- Exposes GPUs to Kubernetes scheduler

#### Monitoring Stack
- **Prometheus**: Metrics collection
- **NVIDIA DCGM Exporter**: GPU metrics
- **Grafana**: Visualization dashboard
- **Alert Rules**: GPU health monitoring

### 3. Cost Governance Layer

- Log Analytics Workspace
- Budget Management with alerts
- Resource tagging strategy

## Data Flow

### Metric Collection
```
GPU Nodes → DCGM Exporter → Prometheus → Grafana Dashboard
```

### Cost Tracking
```
Azure Resources → Resource Tags → Azure Cost Management → Budget Alerts
```

## Autoscaling Behavior

- Cluster autoscaler adjusts node count based on demand
- Spot nodes prefer scale-to-zero when idle
- On-demand maintains minimum capacity

## Cost Optimization Strategies

1. **Spot Instances**: 80-90% savings vs on-demand
2. **Autoscaling**: Pay only for what you use
3. **Scale to Zero**: Spot nodes can scale to 0
4. **Budget Alerts**: Prevent overspending
