variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "region" {
  description = "AWS Region"
  type        = string
}

variable "team_name" {
  description = "Team name"
  type        = string
}

variable "endpoint_subnet_ids" {
  description = "Subnet IDs for the VPC endpoint"
  type        = list(string)
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

variable "sg_map" {
  description = "Security Group Map"
  type        = map(string)
}

variable "rds_log_group_names" {
  description = "RDS CloudWatch Log Groups map"
  type        = map(string)
}

variable "cache_log_group_names" {
  description = "ElastiCache CloudWatch Log Groups map"
  type        = map(string)
}