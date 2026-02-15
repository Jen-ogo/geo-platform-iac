variable "postgres_server_name" {
  type        = string
  description = "Postgres Flexible Server name"
  default     = "geo-pg"
}

variable "postgres_sku_name" {
  type        = string
  description = "SKU for Postgres Flexible Server"
  default     = "B_Standard_B1ms"
}

variable "postgres_version" {
  type        = string
  description = "Postgres engine major version"
  default     = "16"
}

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