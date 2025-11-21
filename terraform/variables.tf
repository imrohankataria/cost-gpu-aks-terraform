variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "rg-aks-gpu-cluster"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "eastus"
}

variable "cluster_name" {
  description = "Name of the AKS cluster"
  type        = string
  default     = "aks-gpu-cluster"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.28.0"
}

variable "cost_center" {
  description = "Cost center for billing"
  type        = string
  default     = "engineering"
}

# Network Configuration
variable "vnet_address_space" {
  description = "Address space for the virtual network"
  type        = string
  default     = "10.1.0.0/16"
}

variable "aks_subnet_address_prefix" {
  description = "Address prefix for the AKS subnet"
  type        = string
  default     = "10.1.1.0/24"
}

# System Node Pool Configuration
variable "system_node_count" {
  description = "Initial number of nodes in system pool"
  type        = number
  default     = 2
}

variable "system_node_min_count" {
  description = "Minimum number of nodes in system pool"
  type        = number
  default     = 1
}

variable "system_node_max_count" {
  description = "Maximum number of nodes in system pool"
  type        = number
  default     = 3
}

variable "system_node_size" {
  description = "VM size for system nodes"
  type        = string
  default     = "Standard_D4s_v3"
}

# GPU Node Configuration
variable "gpu_node_size" {
  description = "VM size for GPU nodes (NC-series for NVIDIA GPUs)"
  type        = string
  default     = "Standard_NC6s_v3"
}

# GPU Spot Node Pool Configuration
variable "gpu_spot_node_count" {
  description = "Initial number of GPU spot nodes"
  type        = number
  default     = 1
}

variable "gpu_spot_min_count" {
  description = "Minimum number of GPU spot nodes"
  type        = number
  default     = 0
}

variable "gpu_spot_max_count" {
  description = "Maximum number of GPU spot nodes"
  type        = number
  default     = 10
}

variable "spot_max_price" {
  description = "Maximum price for spot instances (-1 for market price)"
  type        = number
  default     = -1
}

# GPU On-Demand Node Pool Configuration
variable "gpu_ondemand_node_count" {
  description = "Initial number of GPU on-demand nodes"
  type        = number
  default     = 1
}

variable "gpu_ondemand_min_count" {
  description = "Minimum number of GPU on-demand nodes"
  type        = number
  default     = 1
}

variable "gpu_ondemand_max_count" {
  description = "Maximum number of GPU on-demand nodes"
  type        = number
  default     = 5
}

# Monitoring and Logging
variable "log_retention_days" {
  description = "Number of days to retain logs"
  type        = number
  default     = 30
}

# Cost Governance
variable "monthly_budget_amount" {
  description = "Monthly budget amount in USD"
  type        = number
  default     = 5000
}

variable "budget_alert_emails" {
  description = "List of email addresses for budget alerts"
  type        = list(string)
  default     = []
}

# Tags
variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    "Project"     = "AKS-GPU-Cost-Optimization"
    "Terraform"   = "true"
  }
}
