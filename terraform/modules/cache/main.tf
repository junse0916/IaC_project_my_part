## elasticache 서브넷 그룹 생성 및 valkey 생성
resource "aws_elasticache_subnet_group" "cache" {
  name       = "eks-cache-subnet-group"
  subnet_ids = var.subnet_ids
}

resource "aws_elasticache_replication_group" "main" {
  for_each = var.cache_valkey

  replication_group_id = each.value.name
  description          = each.value.description
  engine               = each.value.engine
  engine_version       = each.value.engine_version
  node_type            = each.value.node_type
  port                 = each.value.port

  num_cache_clusters         = each.value.num_cache_clusters
  automatic_failover_enabled = each.value.automatic_failover_enabled
  multi_az_enabled           = each.value.multi_az_enabled

  subnet_group_name = aws_elasticache_subnet_group.cache.name

  security_group_ids = [
    for name in each.value.sg_names :
    var.sg_map[name]
  ]

  log_delivery_configuration {
    destination      = aws_cloudwatch_log_group.cache["${each.key}-slow-log"].name
    destination_type = "cloudwatch-logs"
    log_format       = "json"
    log_type         = "slow-log"
  }
  log_delivery_configuration {
    destination      = aws_cloudwatch_log_group.cache["${each.key}-engine-log"].name
    destination_type = "cloudwatch-logs"
    log_format       = "json"
    log_type         = "engine-log"
  }

  depends_on = [aws_cloudwatch_log_group.cache]

  tags = {
    Name = each.value.name
  }
}

data "aws_kms_key" "log_key" {
  key_id = "alias/${var.log_pipeline.kms_key.log_key_alias}"
}

locals {
  cache_log_groups = merge([
    for cache_key, cache in var.cache_valkey : {
      for log_type in ["slow-log", "engine-log"] :
      "${cache_key}-${log_type}" => {
        cache_name = cache.name
        log_type   = log_type
      }
    }
  ]...)
}

resource "aws_cloudwatch_log_group" "cache" {
  for_each = local.cache_log_groups

  name                        = "/aws/elasticache/${each.value.cache_name}/${each.value.log_type}"
  retention_in_days           = var.log_pipeline.log_group.retention_in_days
  log_group_class             = var.log_pipeline.log_group.log_group_class
  kms_key_id                  = data.aws_kms_key.log_key.arn
  deletion_protection_enabled = var.log_pipeline.log_group.deletion_protection_enabled
}