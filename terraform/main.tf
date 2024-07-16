terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.111.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.suscriptionId
  tenant_id       = var.tenantId
  # skip_provider_registration = true --> En caso de que el usuario no tenga acceso a la creación de recursos
}