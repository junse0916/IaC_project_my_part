variable "region_name" {
  description = "AWS region label used in resource names"
  type        = string
}

variable "vpc_id" {
  description = "VPC attached to the Transit Gateway"
  type        = string
}

variable "attachment_subnet_ids" {
  description = "One private subnet per AZ for the TGW VPC attachment"
  type        = list(string)
}

variable "private_route_table_ids" {
  description = "VPC private route tables that need on-premises routes through the TGW"
  type        = list(string)
}

variable "public_route_table_ids" {
  description = "VPC public route tables used by internet-facing ALBs with Hybrid Pod IP targets"
  type        = list(string)
  default     = []
}

variable "public_route_cidrs" {
  description = "Hybrid Pod CIDRs reachable from public ALB subnets through the TGW"
  type        = set(string)
  default     = []
}

variable "vpn" {
  description = "TGW and c3745 Site-to-Site VPN settings"
  type = object({
    enabled          = bool
    routing_profile  = string
    aws_bgp_asn      = number
    vpn_ecmp_support = bool

    customer_gateways = map(object({
      public_ip = string
      bgp_asn   = number
      # Which TGW route table this gateway is associated with.
      # "idc" = R1/R2 (site-to-site to the on-prem network).
      # "security_zone" = FW-SEC / Security R1 (Connection C).
      zone = string
    }))

    vpc_route_cidrs = set(string)
  })

  validation {
    condition     = contains(["lab_redundant", "ecmp"], var.vpn.routing_profile)
    error_message = "vpn.routing_profile must be lab_redundant or ecmp."
  }

  validation {
    condition     = !var.vpn.enabled || length(var.vpn.customer_gateways) >= 1
    error_message = "At least one customer gateway is required when VPN is enabled."
  }

  validation {
    condition = length(distinct([
      for gateway in values(var.vpn.customer_gateways) : "${gateway.public_ip}|${gateway.bgp_asn}"
    ])) == length(var.vpn.customer_gateways)
    error_message = "AWS rejected duplicate public_ip + bgp_asn Customer Gateway pairs in the 2026-07-15 lab. Use distinct ASNs for a shared-IP lab or distinct public IPs for the ECMP profile."
  }

  validation {
    condition = var.vpn.routing_profile != "ecmp" || (
      var.vpn.vpn_ecmp_support &&
      length(distinct([for gateway in values(var.vpn.customer_gateways) : gateway.bgp_asn])) == 1 &&
      length(distinct([for gateway in values(var.vpn.customer_gateways) : gateway.public_ip])) == length(var.vpn.customer_gateways)
    )
    error_message = "The ecmp profile requires VPN ECMP support, one shared customer ASN/AS_PATH, and a distinct public IP for every Customer Gateway."
  }

  validation {
    condition     = !contains(var.vpn.vpc_route_cidrs, "169.254.0.0/16")
    error_message = "Do not route the VPN tunnel link-local range through the VPC. Advertise an IDC or explicit test-source prefix instead."
  }

  validation {
    condition = alltrue([
      for gateway in values(var.vpn.customer_gateways) : contains(["idc", "security_zone"], gateway.zone)
    ])
    error_message = "Each customer gateway's zone must be idc or security_zone (idc-vpn-routing-stp-plan.md section 3.3's two TGW route table domains)."
  }
}
