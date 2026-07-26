terraform {
  required_version = ">= 1.6"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }
    databricks = {
      source  = "databricks/databricks"
      version = "~> 1.0"
    }
  }
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs
provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

# https://registry.terraform.io/providers/hashicorp/azuread/latest/docs
provider "azuread" {}

# https://registry.terraform.io/providers/databricks/databricks/latest/docs
provider "databricks" {
  host = var.dbx_host
  #token = var.dbx_token  # if you want to use DBX token to auth
}
