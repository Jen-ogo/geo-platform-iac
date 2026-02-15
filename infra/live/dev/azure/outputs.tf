output "location" {
  value = azurerm_resource_group.rg_geo_dbx.location
}

output "resource_group_name" {
  value = azurerm_resource_group.rg_geo_dbx.name
}

output "storage_account_name" {
  value = azurerm_storage_account.stgeodbxuc.name
}

output "storage_account_id" {
  value = azurerm_storage_account.stgeodbxuc.id
}

output "uc_root_container" {
  value = azurerm_storage_container.uc_root.name
}

output "snowpipe_queues" {
  value = {
    osm      = azurerm_storage_queue.snowpipe_osm.name
    gisco    = azurerm_storage_queue.snowpipe_gisco.name
    eurostat = azurerm_storage_queue.snowpipe_eurostat.name
  }
}

output "key_vault_name" {
  value = azurerm_key_vault.kv_geo_dbx_sub.name
}

output "key_vault_id" {
  value = azurerm_key_vault.kv_geo_dbx_sub.id
}

output "postgres_server_name" {
  value = azurerm_postgresql_flexible_server.geo_pg.name
}

output "postgres_fqdn" {
  value = azurerm_postgresql_flexible_server.geo_pg.fqdn
}

output "postgres_id" {
  value = azurerm_postgresql_flexible_server.geo_pg.id
}

output "databricks_workspace_name" {
  value = azurerm_databricks_workspace.geo_databricks_sub.name
}

output "databricks_workspace_id" {
  value = azurerm_databricks_workspace.geo_databricks_sub.id
}

output "databricks_workspace_url" {
  value = azurerm_databricks_workspace.geo_databricks_sub.workspace_url
}

output "eventhub_namespace_name" {
  value = azurerm_eventhub_namespace.geo_databricks_sub.name
}

output "eventhub_namespace_id" {
  value = azurerm_eventhub_namespace.geo_databricks_sub.id
}

output "adf_name" {
  value = azurerm_data_factory.adf_geo_platform.name
}

output "adf_id" {
  value = azurerm_data_factory.adf_geo_platform.id
}