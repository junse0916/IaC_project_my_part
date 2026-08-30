output "arn" {
  description = "ALB ARN"
  value       = aws_lb.this.arn
}

output "arn_suffix" {
  description = "ALB ARN suffix for CloudWatch metrics"
  value       = aws_lb.this.arn_suffix
}

output "dns_name" {
  description = "AWS-generated ALB DNS name"
  value       = aws_lb.this.dns_name
}

output "zone_id" {
  description = "ALB canonical hosted zone ID"
  value       = aws_lb.this.zone_id
}

output "origin_domain_name" {
  description = "Route 53 hostname mapped to the ALB"
  value       = aws_route53_record.origin.fqdn
}

output "target_group_arn" {
  description = "Empty target group ARN for a future TargetGroupBinding"
  value       = aws_lb_target_group.was.arn
}

output "target_group_name" {
  description = "Empty target group name for a future TargetGroupBinding"
  value       = aws_lb_target_group.was.name
}

output "https_listener_arn" {
  description = "HTTPS listener ARN, or null until certificate_arn is configured"
  value       = try(aws_lb_listener.https[0].arn, null)
}
