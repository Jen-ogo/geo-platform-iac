variable "subscription_id" {
  type        = string
  description = "Azure subscription id for azurerm provider"
}

variable "location" {
  type        = string
  description = "Azure region for this environment"
  default     = "westeurope"
}

variable "resource_group_name" {
  type        = string
  description = "Primary resource group for the geo platform"
  default     = "rg-geo-dbx"
}

variable "managed_resource_group_name" {
  type        = string
  description = "Databricks managed resource group name"
  default     = "auto"
}