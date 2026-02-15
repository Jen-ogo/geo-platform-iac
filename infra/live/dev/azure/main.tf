
data "azurerm_client_config" "current" {}

# Read Postgres password from Key Vault (preferred)
# NOTE: secret value is NOT stored in state in plaintext by Terraform, but it will be present
# in state as a sensitive value. Keep state remote + protected.
# This expects the Key Vault + secret to already exist (you already created it via az CLI).

data "azurerm_key_vault" "kv" {
  name                = var.key_vault_name
  resource_group_name = azurerm_resource_group.rg_geo_dbx.name
}

data "azurerm_key_vault_secret" "pg_admin_password" {
  name         = var.pg_admin_password_secret_name
  key_vault_id = data.azurerm_key_vault.kv.id
}

locals {
  pg_admin_login    = coalesce(var.postgres_admin_login, "ev_user")
  pg_admin_password = coalesce(var.postgres_admin_password, data.azurerm_key_vault_secret.pg_admin_password.value)
}

# NOTE: Postgres Flexible Server resource schema requires admin credentials.
# We keep them OPTIONAL so you can source secrets from Key Vault without hardcoding.
variable "postgres_admin_login" {
  type        = string
  description = "Admin login for existing Postgres Flexible Server. If null, default is used."
  default     = null
}

variable "postgres_admin_password" {
  type        = string
  description = "Admin password for existing Postgres Flexible Server. If null, value is read from Key Vault secret."
  sensitive   = true
  default     = null
}

# Where to read the password from (Key Vault)
variable "key_vault_name" {
  type        = string
  description = "Key Vault name that stores secrets for this environment."
  default     = "kv-geo-dbx-sub"
}

variable "pg_admin_password_secret_name" {
  type        = string
  description = "Key Vault secret name for Postgres admin password."
  default     = "pg-geo-pg-admin-password"
}

# 1.1 Resource Groups

resource "azurerm_resource_group" "auto" {
  name     = "auto"
  location = "westeurope"

  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      managed_by,
      tags
    ]
  }
}

resource "azurerm_resource_group" "rg_geo_dbx" {
  name     = "rg-geo-dbx"
  location = "westeurope"

  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      tags
    ]
  }
}

# 1.2 Storage Accounts
resource "azurerm_storage_account" "stgeodbxuc" {
  name                     = "stgeodbxuc"
  resource_group_name      = azurerm_resource_group.rg_geo_dbx.name
  location                 = azurerm_resource_group.rg_geo_dbx.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  # IMPORTANT: this account is ADLS Gen2 (HNS enabled). If this is missing/false,
  # Terraform will FORCE REPLACEMENT of the storage account.
  is_hns_enabled = true

  # Keep current safety posture (avoid accidental public exposure)
  allow_nested_items_to_be_public = true

  # Preserve existing retention settings seen in the plan output (otherwise TF will try to remove them)
  blob_properties {
    change_feed_enabled      = false
    last_access_time_enabled = false
    versioning_enabled       = false

    container_delete_retention_policy {
      days = 7
    }

    delete_retention_policy {
      days                     = 7
      permanent_delete_enabled = false
    }
  }

  queue_properties {
    hour_metrics {
      enabled               = false
      include_apis          = false
      retention_policy_days = 1
      version               = "1.0"
    }

    logging {
      delete                = false
      read                  = false
      retention_policy_days = 1
      version               = "1.0"
      write                 = false
    }

    minute_metrics {
      enabled               = false
      include_apis          = false
      retention_policy_days = 1
      version               = "1.0"
    }
  }

  share_properties {
    retention_policy {
      days = 7
    }
  }

  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      tags,
      # AzureRM provider v4+ has some properties that drift/are computed; ignore during import bootstrap
      blob_properties,
      queue_properties,
      share_properties,
      routing,
      static_website,
      network_rules,
      custom_domain,
      azure_files_authentication,
      identity,
      immutability_policy,
      sas_policy,
      # keep HNS as a hard requirement; do NOT ignore is_hns_enabled
      allow_nested_items_to_be_public
    ]
  }
}

# 1.3 Storage Container(s) (Data Lake Gen2)
# Existing container: uc-root
resource "azurerm_storage_container" "uc_root" {
  name                  = "uc-root"
  storage_account_name  = azurerm_storage_account.stgeodbxuc.name
  container_access_type = "private"

  lifecycle {
    prevent_destroy = true
  }
}

# 1.4 Storage Queues (Snowpipe notifications)
resource "azurerm_storage_queue" "snowpipe_osm" {
  name                 = "snowpipe-osm"
  storage_account_name = azurerm_storage_account.stgeodbxuc.name

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_storage_queue" "snowpipe_gisco" {
  name                 = "snowpipe-gisco"
  storage_account_name = azurerm_storage_account.stgeodbxuc.name

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_storage_queue" "snowpipe_eurostat" {
  name                 = "snowpipe-eurostat"
  storage_account_name = azurerm_storage_account.stgeodbxuc.name

  lifecycle {
    prevent_destroy = true
  }
}

# 1.5 Databricks Workspace
resource "azurerm_databricks_workspace" "geo_databricks_sub" {
  name                = "geo-databricks-sub"
  resource_group_name = azurerm_resource_group.rg_geo_dbx.name
  location            = azurerm_resource_group.rg_geo_dbx.location

  # UC is typically Premium; if the import/plan shows drift, we will adjust to match Azure.
  sku = "premium"

  # IMPORTANT: Databricks Workspace already uses an existing managed resource group named `auto`.
  # Keep it as a literal to avoid accidental drift if the `auto` RG block is renamed.
  managed_resource_group_name = "auto"

  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      tags,
      # Keep import stable; we'll tighten this after we see a clean plan
      custom_parameters,
      infrastructure_encryption_enabled,
      public_network_access_enabled,
      network_security_group_rules_required,
      load_balancer_backend_address_pool_id,
      access_connector_id,
      customer_managed_key_enabled,
      managed_disk_cmk_key_vault_key_id,
      managed_services_cmk_key_vault_key_id
    ]
  }
}

# 1.6 Event Hubs Namespace (name совпадает с Databricks workspace)
# Azure resource: Microsoft.EventHub/namespaces/geo-databricks-sub
resource "azurerm_eventhub_namespace" "geo_databricks_sub" {
  name                = "geo-databricks-sub"
  location            = azurerm_resource_group.rg_geo_dbx.location
  resource_group_name = azurerm_resource_group.rg_geo_dbx.name

  sku      = "Standard"
  capacity = 1

  tags = {
    application = "databricks"
  }

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [tags]
  }
}

# 1.7 Azure Data Factory
# Azure resource: Microsoft.DataFactory/factories/adf-geo-platform
resource "azurerm_data_factory" "adf_geo_platform" {
  name                = "adf-geo-platform"
  location            = azurerm_resource_group.rg_geo_dbx.location
  resource_group_name = azurerm_resource_group.rg_geo_dbx.name

  identity {
    type = "SystemAssigned"
  }

  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      tags,
      identity,
      github_configuration,
      global_parameter,
      managed_virtual_network_enabled,
      public_network_enabled
    ]
  }
}

# 1.8 Key Vault
# Azure resource: Microsoft.KeyVault/vaults/kv-geo-dbx-sub
resource "azurerm_key_vault" "kv_geo_dbx_sub" {
  name                = "kv-geo-dbx-sub"
  location            = azurerm_resource_group.rg_geo_dbx.location
  resource_group_name = azurerm_resource_group.rg_geo_dbx.name

  tenant_id = data.azurerm_client_config.current.tenant_id
  sku_name  = "standard"

  # Keep safe defaults; if your existing vault differs, we will tune after import.
  purge_protection_enabled = false
  # IMPORTANT: keep the CURRENT Azure setting to avoid unintended changes after import
  # We'll tighten/parameterize later if you decide to change it intentionally.
  soft_delete_retention_days = 90

  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      tags,
      access_policy,
      network_acls,
      contact,
      enable_rbac_authorization
    ]
  }
}

# 1.9 PostgreSQL Flexible Server
# Azure resource: Microsoft.DBforPostgreSQL/flexibleServers/geo-pg
resource "azurerm_postgresql_flexible_server" "geo_pg" {
  name                = "geo-pg"
  location            = azurerm_resource_group.rg_geo_dbx.location
  resource_group_name = azurerm_resource_group.rg_geo_dbx.name

  # From `az resource list` output: SKU = Standard_B1ms (Burstable)
  sku_name = "B_Standard_B1ms"

  # Required by provider schema even when importing. Use real values via dev.tfvars.
  administrator_login    = local.pg_admin_login
  administrator_password = local.pg_admin_password

  # Match current server version (from `az postgres flexible-server show/update` output)
  version = "16"

  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      tags,
      administrator_login,
      administrator_password,
      zone,
      delegated_subnet_id,
      private_dns_zone_id,
      high_availability,
      storage_mb,
      backup_retention_days,
      geo_redundant_backup_enabled,
      maintenance_window,
      authentication,
      customer_managed_key,
      identity
    ]
  }
}

# -----------------------------------------------------------------------------
# IMPORT COMMANDS (for reference)
# -----------------------------------------------------------------------------
# terraform import -var-file=dev.tfvars azurerm_eventhub_namespace.geo_databricks_sub \
#   /subscriptions/0c5ec135-47e0-49ba-ba85-7b3a9a87234d/resourceGroups/rg-geo-dbx/providers/Microsoft.EventHub/namespaces/geo-databricks-sub
#
# terraform import -var-file=dev.tfvars azurerm_data_factory.adf_geo_platform \
#   /subscriptions/0c5ec135-47e0-49ba-ba85-7b3a9a87234d/resourceGroups/rg-geo-dbx/providers/Microsoft.DataFactory/factories/adf-geo-platform
#
# terraform import -var-file=dev.tfvars azurerm_key_vault.kv_geo_dbx_sub \
#   /subscriptions/0c5ec135-47e0-49ba-ba85-7b3a9a87234d/resourceGroups/rg-geo-dbx/providers/Microsoft.KeyVault/vaults/kv-geo-dbx-sub
#
# terraform import -var-file=dev.tfvars azurerm_postgresql_flexible_server.geo_pg \
#   /subscriptions/0c5ec135-47e0-49ba-ba85-7b3a9a87234d/resourceGroups/rg-geo-dbx/providers/Microsoft.DBforPostgreSQL/flexibleServers/geo-pg
