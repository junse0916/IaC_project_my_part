variable "name" {
  description = "Application Load Balancer name"
  type        = string
}

variable "target_group_name" {
  description = "Empty target group name; workloads are registered later"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for the ALB target group"
  type        = string
}

variable "subnet_ids" {
  description = "Public subnet IDs for the internet-facing ALB"
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security groups attached to the ALB"
  type        = list(string)
}

variable "internal" {
  description = "Whether the ALB is internal"
  type        = bool
  default     = false
}

variable "ip_address_type" {
  description = "ALB IP address type"
  type        = string
  default     = "ipv4"

  validation {
    condition     = contains(["ipv4", "dualstack", "dualstack-without-public-ipv4"], var.ip_address_type)
    error_message = "ip_address_type must be ipv4, dualstack, or dualstack-without-public-ipv4."
  }
}

variable "certificate_arn" {
  description = "ACM certificate ARN for the HTTPS listener; leave empty until issued"
  type        = string
  default     = ""
}

variable "https_enabled" {
  description = "Explicitly enable HTTPS when certificate_arn is not known until apply"
  type        = bool
  default     = null
  nullable    = true
}

variable "ssl_policy" {
  description = "TLS security policy for the HTTPS listener"
  type        = string
  default     = "ELBSecurityPolicy-TLS13-1-2-2021-06"
}

variable "target_port" {
  description = "Default port used by the IP target group"
  type        = number
  default     = 8080
}

variable "health_check_path" {
  description = "Target group health check path"
  type        = string
  default     = "/api/v1/health"
}

variable "health_check_matcher" {
  description = "Successful health check HTTP status codes"
  type        = string
  default     = "200"
}

variable "idle_timeout" {
  description = "ALB idle timeout in seconds; raised for SSE connections"
  type        = number
  default     = 120
}

variable "deletion_protection" {
  description = "Enable ALB deletion protection"
  type        = bool
  default     = false
}

variable "hosted_zone_name" {
  description = "Public Route 53 hosted zone name"
  type        = string
}

variable "origin_domain_name" {
  description = "Route 53 origin hostname mapped to the ALB"
  type        = string
}

variable "tags" {
  description = "Tags applied to ALB resources"
  type        = map(string)
  default     = {}
}
