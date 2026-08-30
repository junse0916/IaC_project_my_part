variable "subnet_ids" {
  description = "aws vpc 서브넷 ids"
  type        = list(string)
}

variable "sg_map" {
  description = "보안그룹 맵"
  type        = map(string)
}

variable "cache_valkey" {
  type = map(object({
    engine                     = string
    engine_version             = string
    name                       = string
    description                = string
    node_type                  = string
    port                       = number
    num_cache_clusters         = number
    automatic_failover_enabled = bool
    multi_az_enabled           = bool
    sg_names                   = list(string)
  }))
}

variable "log_pipeline" {
  description = "Log pipeline configuration"
  type = object({
    kinesis_stream = object({
      encryption_type = string
    })
    log_group = object({
      retention_in_days           = number
      log_group_class             = string
      deletion_protection_enabled = bool
    })
    subscription_filter = object({
      filter_pattern = string
      distribution   = string
    })
    vpc_endpoint = object({
      vpc_endpoint_type   = string
      private_dns_enabled = bool
      sg_names            = list(string)
    })
    kms_key = object({
      log_key_alias = string
      rds_key_alias = string
    })
    cloudtrail = object({
      force_destroy                 = bool
      include_global_service_events = bool
      is_multi_region_trail         = bool
      enable_log_file_validation    = bool
    })
  })
}