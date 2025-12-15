terraform {
  required_version = ">= 1.7.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.29.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.13.0"
    }
  }
}

provider "azurerm" {
  subscription_id = var.azure_subscription_id
  resource_provider_registrations = "none"
  features {}
}

variable "azure_subscription_id" {
  description = "Azure subscription ID to deploy AKS into"
  type        = string
}

# --- basic AKS infra ---

resource "azurerm_resource_group" "rg" {
  name     = "rg-aks-envoy-demo"
  location = "westeurope"
}

resource "azurerm_kubernetes_cluster" "default" {
  name                = "aks-envoy-demo"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "envoydemo"

  default_node_pool {
    name       = "system"
    node_count = 1
    vm_size    = "Standard_D2s_v3"
  }

  identity {
    type = "SystemAssigned"
  }

  sku_tier = "Free"
}


data "azurerm_client_config" "current" {}

data "azurerm_subscription" "current" {}

# --- kube + helm providers bound to this AKS ---

provider "kubernetes" {
  host                   = azurerm_kubernetes_cluster.default.kube_config[0].host
  client_certificate     = base64decode(azurerm_kubernetes_cluster.default.kube_config[0].client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.default.kube_config[0].client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.default.kube_config[0].cluster_ca_certificate)
}
