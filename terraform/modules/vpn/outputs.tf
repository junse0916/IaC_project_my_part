output "transit_gateway_id" {
  description = "Transit Gateway ID, or null when vpn.enabled is false"
  value       = try(aws_ec2_transit_gateway.main[0].id, null)
}

output "idc_route_table_id" {
  description = "TGW route table associated with the VPC attachment and R1/R2"
  value       = try(aws_ec2_transit_gateway_route_table.idc[0].id, null)
}

output "security_zone_route_table_id" {
  description = "TGW route table associated with FW-SEC / Security R1 (Connection C)"
  value       = try(aws_ec2_transit_gateway_route_table.security_zone[0].id, null)
}

output "vpc_attachment_id" {
  description = "TGW VPC attachment ID"
  value       = try(aws_ec2_transit_gateway_vpc_attachment.main[0].id, null)
}

output "customer_gateway_ids" {
  description = "c3745 Customer Gateway IDs"
  value       = { for key, gateway in aws_customer_gateway.c3745 : key => gateway.id }
}

output "vpn_connection_ids" {
  description = "c3745 Site-to-Site VPN Connection IDs"
  value       = { for key, connection in aws_vpn_connection.c3745 : key => connection.id }
}

output "tunnel_addresses" {
  description = "AWS public tunnel endpoint addresses for each c3745 VPN Connection"
  value = {
    for key, connection in aws_vpn_connection.c3745 : key => {
      tunnel1 = connection.tunnel1_address
      tunnel2 = connection.tunnel2_address
    }
  }
}

output "tunnel_bgp_addresses" {
  description = "AWS and c3745 BGP inside addresses for both tunnels"
  value = {
    for key, connection in aws_vpn_connection.c3745 : key => {
      tunnel1_aws   = connection.tunnel1_vgw_inside_address
      tunnel1_c3745 = connection.tunnel1_cgw_inside_address
      tunnel2_aws   = connection.tunnel2_vgw_inside_address
      tunnel2_c3745 = connection.tunnel2_cgw_inside_address
    }
  }
}

output "tunnel_preshared_keys" {
  description = "Pre-shared keys for both tunnels of each VPN Connection"
  value = {
    for key, connection in aws_vpn_connection.c3745 : key => {
      tunnel1 = connection.tunnel1_preshared_key
      tunnel2 = connection.tunnel2_preshared_key
    }
  }
  sensitive = true
}



output "render_data" {
  description = "Per-gateway fields needed to render a c3745 IOS VPN config (local/AWS ASN, tunnel outside/inside addresses, PSKs, zone). Consumed by scripts/render-vpn-ios-config.sh instead of downloading the config from the AWS console."
  sensitive   = true
  value = {
    for key, connection in aws_vpn_connection.c3745 : key => {
      zone                           = local.customer_gateways[key].zone
      local_public_ip                = local.customer_gateways[key].public_ip
      local_asn                      = local.customer_gateways[key].bgp_asn
      aws_asn                        = var.vpn.aws_bgp_asn
      vpn_connection_id              = connection.id
      customer_gateway_configuration = connection.customer_gateway_configuration
      tunnel1 = {
        outside_ip   = connection.tunnel1_address
        aws_inside   = connection.tunnel1_vgw_inside_address
        c3745_inside = connection.tunnel1_cgw_inside_address
        psk          = connection.tunnel1_preshared_key
      }
      tunnel2 = {
        outside_ip   = connection.tunnel2_address
        aws_inside   = connection.tunnel2_vgw_inside_address
        c3745_inside = connection.tunnel2_cgw_inside_address
        psk          = connection.tunnel2_preshared_key
      }
    }
  }
}
