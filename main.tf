resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_log_analytics_workspace" "main" {
  count               = var.enable_log_analytics ? 1 : 0
  name                = "${var.cluster_name}-logs"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = var.log_analytics_workspace_sku
  retention_in_days   = var.log_retention_days
  tags                = var.tags
}

resource "azurerm_kubernetes_cluster" "main" {
  name                = var.cluster_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = var.dns_prefix
  kubernetes_version  = var.kubernetes_version

  default_node_pool {
    name                = "system"
    node_count          = var.system_node_count
    vm_size             = var.system_node_vm_size
    max_pods            = var.max_pods_per_node
    enable_auto_scaling = false
    type                = "VirtualMachineScaleSets"

    tags = merge(
      var.tags,
      {
        "nodepool-type" = "system"
      }
    )
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin = var.network_plugin
    network_policy = var.network_policy
  }

  dynamic "oms_agent" {
    for_each = var.enable_log_analytics ? [1] : []
    content {
      log_analytics_workspace_id = azurerm_log_analytics_workspace.main[0].id
    }
  }

  azure_policy_enabled              = var.enable_azure_policy
  role_based_access_control_enabled = var.enable_rbac

  tags = var.tags

  lifecycle {
    ignore_changes = [
      default_node_pool[0].node_count
    ]
  }
}

resource "azurerm_kubernetes_cluster_node_pool" "gpu" {
  name                  = "gpu"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
  vm_size               = var.gpu_node_vm_size
  node_count            = var.enable_auto_scaling ? null : var.gpu_node_count
  enable_auto_scaling   = var.enable_auto_scaling
  min_count             = var.enable_auto_scaling ? var.gpu_node_min_count : null
  max_count             = var.enable_auto_scaling ? var.gpu_node_max_count : null
  max_pods              = var.max_pods_per_node
  priority              = var.spot_instances_enabled ? "Spot" : "Regular"
  eviction_policy       = var.spot_instances_enabled ? "Delete" : null
  spot_max_price        = var.spot_instances_enabled ? var.spot_max_price : null
  node_taints           = var.gpu_node_taints

  node_labels = {
    "workload"       = "gpu"
    "gpu-enabled"    = "true"
    "cost-optimized" = var.spot_instances_enabled ? "true" : "false"
  }

  tags = merge(
    var.tags,
    {
      "nodepool-type" = "gpu"
      "gpu-enabled"   = "true"
    }
  )

  lifecycle {
    ignore_changes = [
      node_count
    ]
  }
}
