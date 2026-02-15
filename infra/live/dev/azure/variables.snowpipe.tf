variable "eventhub_namespace_name" {
  type        = string
  description = "Event Hubs namespace name"
  default     = "geo-databricks-sub"
}

variable "data_factory_name" {
  type        = string
  description = "Azure Data Factory name"
  default     = "adf-geo-platform"
}

variable "key_vault_name" {
  type        = string
  description = "Key Vault name that stores secrets for this environment"
  default     = "kv-geo-dbx-sub"
}

variable "pg_admin_password_secret_name" {
  type        = string
  description = "Key Vault secret name for Postgres admin password"
  default     = "pg-geo-pg-admin-password"
}