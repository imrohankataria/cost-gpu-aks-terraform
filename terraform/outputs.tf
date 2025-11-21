output "cluster_name" {
  description = "Name of the AKS cluster"
  value       = azurerm_kubernetes_cluster.aks.name
}

output "cluster_id" {
  description = "ID of the AKS cluster"
  value       = azurerm_kubernetes_cluster.aks.id
}

output "cluster_fqdn" {
  description = "FQDN of the AKS cluster"
  value       = azurerm_kubernetes_cluster.aks.fqdn
}

output "kube_config" {
  description = "Kubernetes configuration file"
  value       = azurerm_kubernetes_cluster.aks.kube_config_raw
  sensitive   = true
}

output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.rg.name
}

output "location" {
  description = "Location of the resources"
  value       = azurerm_resource_group.rg.location
}

output "log_analytics_workspace_id" {
  description = "ID of the Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.aks.id
}

output "log_analytics_workspace_name" {
  description = "Name of the Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.aks.name
}

output "gpu_spot_node_pool_name" {
  description = "Name of the GPU Spot node pool"
  value       = azurerm_kubernetes_cluster_node_pool.gpu_spot.name
}

output "gpu_ondemand_node_pool_name" {
  description = "Name of the GPU On-Demand node pool"
  value       = azurerm_kubernetes_cluster_node_pool.gpu_ondemand.name
}

output "get_credentials_command" {
  description = "Command to get cluster credentials"
  value       = "az aks get-credentials --resource-group ${azurerm_resource_group.rg.name} --name ${azurerm_kubernetes_cluster.aks.name}"
}
