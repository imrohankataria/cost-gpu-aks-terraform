terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

provider "azurerm" {
  features {}
}

provider "kubernetes" {
  host                   = azurerm_kubernetes_cluster.aks.kube_config.0.host
  client_certificate     = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.cluster_ca_certificate)
}

# Resource Group
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location

  tags = merge(
    var.tags,
    {
      "Environment" = var.environment
      "ManagedBy"   = "Terraform"
      "Purpose"     = "GPU-Cluster-Cost-Optimization"
    }
  )
}

# Virtual Network
resource "azurerm_virtual_network" "vnet" {
  name                = "${var.cluster_name}-vnet"
  address_space       = [var.vnet_address_space]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  tags = var.tags
}

# Subnet for AKS
resource "azurerm_subnet" "aks_subnet" {
  name                 = "${var.cluster_name}-aks-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.aks_subnet_address_prefix]
}

# AKS Cluster
resource "azurerm_kubernetes_cluster" "aks" {
  name                = var.cluster_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "${var.cluster_name}-dns"
  kubernetes_version  = var.kubernetes_version

  default_node_pool {
    name                = "system"
    node_count          = var.system_node_count
    vm_size             = var.system_node_size
    vnet_subnet_id      = azurerm_subnet.aks_subnet.id
    enable_auto_scaling = true
    min_count           = var.system_node_min_count
    max_count           = var.system_node_max_count
    os_disk_size_gb     = 100
    type                = "VirtualMachineScaleSets"
    
    node_labels = {
      "workload" = "system"
    }

    tags = merge(
      var.tags,
      {
        "NodePool" = "system"
      }
    )
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin     = "azure"
    network_policy     = "azure"
    service_cidr       = "10.0.0.0/16"
    dns_service_ip     = "10.0.0.10"
    docker_bridge_cidr = "172.17.0.1/16"
    load_balancer_sku  = "standard"
  }

  azure_policy_enabled = true

  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.aks.id
  }

  tags = merge(
    var.tags,
    {
      "CostCenter" = var.cost_center
    }
  )
}

# GPU Spot Node Pool
resource "azurerm_kubernetes_cluster_node_pool" "gpu_spot" {
  name                  = "gpuspot"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id
  vm_size               = var.gpu_node_size
  node_count            = var.gpu_spot_node_count
  vnet_subnet_id        = azurerm_subnet.aks_subnet.id

  enable_auto_scaling = true
  min_count           = var.gpu_spot_min_count
  max_count           = var.gpu_spot_max_count

  priority        = "Spot"
  eviction_policy = "Delete"
  spot_max_price  = var.spot_max_price

  node_labels = {
    "workload"           = "gpu"
    "kubernetes.azure.com/scalesetpriority" = "spot"
    "gpu-type"           = "nvidia"
  }

  node_taints = [
    "kubernetes.azure.com/scalesetpriority=spot:NoSchedule"
  ]

  tags = merge(
    var.tags,
    {
      "NodePool"   = "gpu-spot"
      "CostSaving" = "true"
    }
  )
}

# GPU On-Demand Node Pool
resource "azurerm_kubernetes_cluster_node_pool" "gpu_ondemand" {
  name                  = "gpuod"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id
  vm_size               = var.gpu_node_size
  node_count            = var.gpu_ondemand_node_count
  vnet_subnet_id        = azurerm_subnet.aks_subnet.id

  enable_auto_scaling = true
  min_count           = var.gpu_ondemand_min_count
  max_count           = var.gpu_ondemand_max_count

  priority = "Regular"

  node_labels = {
    "workload"           = "gpu"
    "priority"           = "on-demand"
    "gpu-type"           = "nvidia"
  }

  tags = merge(
    var.tags,
    {
      "NodePool"    = "gpu-ondemand"
      "HighPriority" = "true"
    }
  )
}

# Log Analytics Workspace for monitoring
resource "azurerm_log_analytics_workspace" "aks" {
  name                = "${var.cluster_name}-logs"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_retention_days

  tags = var.tags
}

# Container Insights Solution
resource "azurerm_log_analytics_solution" "container_insights" {
  solution_name         = "ContainerInsights"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  workspace_resource_id = azurerm_log_analytics_workspace.aks.id
  workspace_name        = azurerm_log_analytics_workspace.aks.name

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/ContainerInsights"
  }

  tags = var.tags
}

# Budget Alert for Cost Governance
resource "azurerm_consumption_budget_resource_group" "budget" {
  name              = "${var.cluster_name}-budget"
  resource_group_id = azurerm_resource_group.rg.id

  amount     = var.monthly_budget_amount
  time_grain = "Monthly"

  time_period {
    start_date = formatdate("YYYY-MM-01'T'00:00:00Z", timestamp())
  }

  notification {
    enabled   = true
    threshold = 80
    operator  = "GreaterThan"

    contact_emails = var.budget_alert_emails
  }

  notification {
    enabled   = true
    threshold = 100
    operator  = "GreaterThan"

    contact_emails = var.budget_alert_emails
  }
}
