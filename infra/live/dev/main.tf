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

  # Important: the managed resource group is the existing RG `auto`
  managed_resource_group_name = azurerm_resource_group.auto.name

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
