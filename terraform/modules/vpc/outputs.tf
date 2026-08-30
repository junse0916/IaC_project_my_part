output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_ids" {
  value = [for item in aws_subnet.publics : item.id]
}

output "public_route_table_ids" {
  description = "Public route tables that may need Hybrid Pod CIDR routes through the TGW"
  value       = [aws_route_table.public.id]
}

output "private_eks_subnet_ids" {
  value = [for item in aws_subnet.privates_eks : item.id]
}

output "private_rds_subnet_ids" {
  value = [for item in aws_subnet.privates_rds : item.id]
}

# VPN 모듈이 필요로 하는 출력
output "private_route_table_ids" {
  description = "VPN 경로 전파용 사설 라우팅 테이블 IDs"
  value = (
    var.create_nat_gw
    ? aws_route_table.with_nat_privates[*].id
    : aws_route_table.without_nat_privates[*].id
  )
}
