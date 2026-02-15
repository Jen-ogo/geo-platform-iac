terraform {
  backend "azurerm" {
    resource_group_name  = "rg-geo-tfstate"
    storage_account_name = "stgeotfstate3256128505"
    container_name       = "tfstate"
    key                  = "geo-platform/dev/terraform.tfstate"
  }
}