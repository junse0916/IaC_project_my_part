output "primary_endpoint_addresses" {
  value = {
    for name, group in aws_elasticache_replication_group.main :
    name => group.primary_endpoint_address
  }
}

output "reader_endpoint_addresses" {
  value = {
    for name, group in aws_elasticache_replication_group.main :
    name => group.reader_endpoint_address
  }
}

output "ports" {
  value = {
    for name, group in aws_elasticache_replication_group.main :
    name => group.port
  }
}

output "log_group_names" {
  value = {
    for key, log_group in aws_cloudwatch_log_group.cache : key => log_group.name
  }
}