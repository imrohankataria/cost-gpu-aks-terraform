variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "rg-aks-gpu"
}

variable "location" {
  description = "Azure region where resources will be created"
  type        = string
  default     = "eastus"
}

variable "cluster_name" {
  description = "Name of the AKS cluster"
  type        = string
  default     = "aks-gpu-cluster"
}

variable "kubernetes_version" {
  description = "Kubernetes version for the AKS cluster"
  type        = string
  default     = "1.27.7"
}

variable "dns_prefix" {
  description = "DNS prefix for the AKS cluster"
  type        = string
  default     = "aks-gpu"
}

variable "system_node_count" {
  description = "Number of nodes in the system node pool"
  type        = number
  default     = 1
}

variable "system_node_vm_size" {
  description = "VM size for system node pool"
  type        = string
  default     = "Standard_D2s_v3"
}

variable "gpu_node_count" {
  description = "Initial number of nodes in the GPU node pool"
  type        = number
  default     = 1
}

variable "gpu_node_min_count" {
  description = "Minimum number of nodes in the GPU node pool for autoscaling"
  type        = number
  default     = 0
}

variable "gpu_node_max_count" {
  description = "Maximum number of nodes in the GPU node pool for autoscaling"
  type        = number
  default     = 3
}

variable "gpu_node_vm_size" {
  description = "VM size for GPU node pool (e.g., Standard_NC6s_v3, Standard_NC4as_T4_v3)"
  type        = string
  default     = "Standard_NC4as_T4_v3"
}

variable "enable_auto_scaling" {
  description = "Enable autoscaling for GPU node pool"
  type        = bool
  default     = true
}

variable "max_pods_per_node" {
  description = "Maximum number of pods per node"
  type        = number
  default     = 30
}

variable "network_plugin" {
  description = "Network plugin to use (azure or kubenet)"
  type        = string
  default     = "azure"
}

variable "network_policy" {
  description = "Network policy to use (azure or calico)"
  type        = string
  default     = "azure"
}

variable "enable_rbac" {
  description = "Enable role-based access control"
  type        = bool
  default     = true
}

variable "enable_azure_policy" {
  description = "Enable Azure Policy for AKS"
  type        = bool
  default     = false
}

variable "enable_log_analytics" {
  description = "Enable Log Analytics workspace integration"
  type        = bool
  default     = true
}

variable "log_analytics_workspace_sku" {
  description = "SKU for Log Analytics workspace"
  type        = string
  default     = "PerGB2018"
}

variable "log_retention_days" {
  description = "Log retention in days"
  type        = number
  default     = 30
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Environment = "Development"
    ManagedBy   = "Terraform"
    Purpose     = "GPU-AKS"
  }
}

variable "gpu_node_taints" {
  description = "Taints for GPU nodes to prevent non-GPU workloads from being scheduled"
  type        = list(string)
  default     = ["sku=gpu:NoSchedule"]
}

variable "spot_instances_enabled" {
  description = "Enable spot instances for GPU nodes to reduce costs"
  type        = bool
  default     = false
}

variable "spot_max_price" {
  description = "Maximum price for spot instances (-1 for on-demand price)"
  type        = number
  default     = -1
}
