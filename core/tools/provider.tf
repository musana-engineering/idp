terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.105.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "2.13.2"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.30.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "2.51.0"
    }
  }
}

provider "azurerm" {
  features {}
}

provider "azuread" {
  # Configuration options
}

provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "${data.azurerm_kubernetes_cluster.aks.name}-admin"
}

provider "helm" {
  kubernetes {
    config_path    = "~/.kube/config"
    config_context = "${data.azurerm_kubernetes_cluster.aks.name}-admin"
  }
}
