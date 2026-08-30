locals {
  customer_gateways      = var.vpn.enabled ? var.vpn.customer_gateways : {}
  idc_gateways           = { for k, v in local.customer_gateways : k => v if v.zone == "idc" }
  security_zone_gateways = { for k, v in local.customer_gateways : k => v if v.zone == "security_zone" }
  vpc_route_cidrs        = sort(tolist(var.vpn.vpc_route_cidrs))
  public_route_cidrs     = sort(tolist(var.public_route_cidrs))
}

resource "aws_ec2_transit_gateway" "main" {
  count = var.vpn.enabled ? 1 : 0

  amazon_side_asn                 = var.vpn.aws_bgp_asn
  default_route_table_association = "disable"
  default_route_table_propagation = "disable"
  dns_support                     = "enable"
  vpn_ecmp_support                = var.vpn.vpn_ecmp_support ? "enable" : "disable"

  tags = {
    Name = "${var.region_name}-tgw-main"
  }
}

# Two route domains per idc-vpn-routing-stp-plan.md section 3.3:
# - idc: associated with the VPC attachment and R1/R2. Exposes the VPC CIDR
#   and the Security Zone CIDR toward R1/R2.
# - security_zone: associated with FW-SEC/Security R1 (Connection C). Exposes
#   the VPC CIDR and the IDC pod/service CIDRs toward FW-SEC.
resource "aws_ec2_transit_gateway_route_table" "idc" {
  count = var.vpn.enabled ? 1 : 0

  transit_gateway_id = aws_ec2_transit_gateway.main[0].id

  tags = {
    Name = "${var.region_name}-tgw-rt-idc"
  }
}

resource "aws_ec2_transit_gateway_route_table" "security_zone" {
  count = var.vpn.enabled ? 1 : 0

  transit_gateway_id = aws_ec2_transit_gateway.main[0].id

  tags = {
    Name = "${var.region_name}-tgw-rt-security-zone"
  }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "main" {
  count = var.vpn.enabled ? 1 : 0

  subnet_ids                                      = var.attachment_subnet_ids
  transit_gateway_id                              = aws_ec2_transit_gateway.main[0].id
  vpc_id                                          = var.vpc_id
  dns_support                                     = "enable"
  ipv6_support                                    = "disable"
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false

  tags = {
    Name = "${var.region_name}-tgw-vpc-attachment"
  }
}

resource "aws_customer_gateway" "c3745" {
  for_each = local.customer_gateways

  bgp_asn     = each.value.bgp_asn
  device_name = "${var.region_name}-${each.key}-c3745"
  ip_address  = each.value.public_ip
  type        = "ipsec.1"

  tags = {
    Name           = "${var.region_name}-cgw-${each.key}"
    RoutingProfile = var.vpn.routing_profile
  }
}

resource "aws_vpn_connection" "c3745" {
  for_each = local.customer_gateways

  transit_gateway_id     = aws_ec2_transit_gateway.main[0].id
  customer_gateway_id    = aws_customer_gateway.c3745[each.key].id
  type                   = "ipsec.1"
  static_routes_only     = false
  tunnel1_startup_action = "add"
  tunnel2_startup_action = "add"

  tags = {
    Name           = "${var.region_name}-vpn-${each.key}"
    RoutingProfile = var.vpn.routing_profile
  }
}

# --- VPC attachment: associated with the idc table, propagates into both ---

resource "aws_ec2_transit_gateway_route_table_association" "vpc" {
  count = var.vpn.enabled ? 1 : 0

  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.main[0].id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.idc[0].id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "vpc_to_idc" {
  count = var.vpn.enabled ? 1 : 0

  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.main[0].id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.idc[0].id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "vpc_to_security_zone" {
  count = var.vpn.enabled ? 1 : 0

  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.main[0].id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.security_zone[0].id
}

# --- R1/R2 (idc zone): associated with the idc table, propagate into both ---

resource "aws_ec2_transit_gateway_route_table_association" "idc_vpn" {
  for_each = local.idc_gateways

  transit_gateway_attachment_id  = aws_vpn_connection.c3745[each.key].transit_gateway_attachment_id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.idc[0].id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "idc_vpn_to_idc" {
  for_each = local.idc_gateways

  transit_gateway_attachment_id  = aws_vpn_connection.c3745[each.key].transit_gateway_attachment_id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.idc[0].id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "idc_vpn_to_security_zone" {
  for_each = local.idc_gateways

  transit_gateway_attachment_id  = aws_vpn_connection.c3745[each.key].transit_gateway_attachment_id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.security_zone[0].id
}

# --- FW-SEC (security_zone zone): associated with the security_zone table, ---
# --- propagates into the idc table only (Connection C has no route back to itself) ---

resource "aws_ec2_transit_gateway_route_table_association" "security_zone_vpn" {
  for_each = local.security_zone_gateways

  transit_gateway_attachment_id  = aws_vpn_connection.c3745[each.key].transit_gateway_attachment_id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.security_zone[0].id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "security_zone_vpn_to_idc" {
  for_each = local.security_zone_gateways

  transit_gateway_attachment_id  = aws_vpn_connection.c3745[each.key].transit_gateway_attachment_id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.idc[0].id
}

resource "aws_route" "to_tgw" {
  count = var.vpn.enabled ? length(var.private_route_table_ids) * length(local.vpc_route_cidrs) : 0

  route_table_id         = var.private_route_table_ids[floor(count.index / length(local.vpc_route_cidrs))]
  destination_cidr_block = local.vpc_route_cidrs[count.index % length(local.vpc_route_cidrs)]
  transit_gateway_id     = aws_ec2_transit_gateway.main[0].id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.main]
}

# Internet-facing ALBs live in the public subnets but register Hybrid Pod IPs
# directly through TargetGroupBinding. Their subnet route table therefore also
# needs an explicit path to the remote Pod CIDR; the IGW default route cannot
# carry RFC1918 traffic to the IDC.
resource "aws_route" "public_to_tgw" {
  count = var.vpn.enabled ? length(var.public_route_table_ids) * length(local.public_route_cidrs) : 0

  route_table_id         = var.public_route_table_ids[floor(count.index / length(local.public_route_cidrs))]
  destination_cidr_block = local.public_route_cidrs[count.index % length(local.public_route_cidrs)]
  transit_gateway_id     = aws_ec2_transit_gateway.main[0].id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.main]
}
