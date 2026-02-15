variable "storage_account_name" {
  type        = string
  description = "Storage account name (ADLS Gen2)"
  default     = "stgeodbxuc"
}

variable "uc_root_container" {
  type        = string
  description = "Unity Catalog root container"
  default     = "uc-root"
}

variable "snowpipe_queues" {
  type        = map(string)
  description = "Storage Queue names used by Snowpipe notification integrations"
  default = {
    osm      = "snowpipe-osm"
    gisco    = "snowpipe-gisco"
    eurostat = "snowpipe-eurostat"
  }
}