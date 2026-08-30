output "kinesis_stream_name" {
  value = aws_kinesis_stream.log_stream.name
}

output "kinesis_stream_arn" {
  value = aws_kinesis_stream.log_stream.arn
}

output "waf_log_group_arn" {
  value = trimsuffix(aws_cloudwatch_log_group.waf.arn, ":*")
}

output "resolver_inbound_ips" {
  value = aws_route53_resolver_endpoint.inbound.ip_address[*].ip
}
