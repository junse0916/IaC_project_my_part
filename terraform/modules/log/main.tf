resource "aws_kinesis_stream" "log_stream" {
  name = "${var.team_name}-log-stream"
  stream_mode_details {
    stream_mode = "ON_DEMAND"
  }
  encryption_type = var.log_pipeline.kinesis_stream.encryption_type
  kms_key_id      = data.aws_kms_key.log_key.arn
}

resource "aws_iam_role" "cwl_to_kinesis" {
  name = "${var.team_name}-cwl-to-kinesis-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "logs.${var.region}.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "cwl_to_kinesis" {
  role = aws_iam_role.cwl_to_kinesis.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["kinesis:PutRecord", "kinesis:PutRecords"]
      Resource = aws_kinesis_stream.log_stream.arn
      },
      {
        Effect   = "Allow"
        Action   = ["kms:GenerateDataKey"]
        Resource = data.aws_kms_key.log_key.arn
    }]
  })
}

resource "aws_cloudwatch_log_group" "waf" {
  name                        = "aws-waf-logs-${var.team_name}"
  retention_in_days           = var.log_pipeline.log_group.retention_in_days
  log_group_class             = var.log_pipeline.log_group.log_group_class
  kms_key_id                  = data.aws_kms_key.log_key.arn
  deletion_protection_enabled = var.log_pipeline.log_group.deletion_protection_enabled
}

resource "aws_vpc_endpoint" "kinesis" {
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${var.region}.kinesis-streams"
  vpc_endpoint_type = var.log_pipeline.vpc_endpoint.vpc_endpoint_type
  subnet_ids        = var.endpoint_subnet_ids
  security_group_ids = [
    for name in var.log_pipeline.vpc_endpoint.sg_names :
    var.sg_map[name]
  ]
  private_dns_enabled = var.log_pipeline.vpc_endpoint.private_dns_enabled
}

data "aws_caller_identity" "current" {}

data "aws_kms_key" "log_key" {
  key_id = "alias/${var.log_pipeline.kms_key.log_key_alias}"
}

data "aws_kms_key" "rds_key" {
  key_id = "alias/${var.log_pipeline.kms_key.rds_key_alias}"
}

resource "aws_iam_role" "eventbridge_to_kinesis" {
  name = "${var.team_name}-eventbridge-to-kinesis-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "events.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "eventbridge_to_kinesis" {
  role = aws_iam_role.eventbridge_to_kinesis.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["kinesis:PutRecord", "kinesis:PutRecords"]
        Resource = aws_kinesis_stream.log_stream.arn
      },
      {
        Effect   = "Allow"
        Action   = ["kms:GenerateDataKey"]
        Resource = data.aws_kms_key.log_key.arn
      }
    ]
  })
}

resource "aws_guardduty_detector" "this" {
  enable = true
}

resource "aws_guardduty_detector_feature" "eks_audit_logs" {
  detector_id = aws_guardduty_detector.this.id
  name        = "EKS_AUDIT_LOGS"
  status      = "ENABLED"
}

resource "aws_guardduty_detector_feature" "s3_data_events" {
  detector_id = aws_guardduty_detector.this.id
  name        = "S3_DATA_EVENTS"
  status      = "DISABLED"
}

resource "aws_guardduty_detector_feature" "ebs_malware_protection" {
  detector_id = aws_guardduty_detector.this.id
  name        = "EBS_MALWARE_PROTECTION"
  status      = "DISABLED"
}

resource "aws_guardduty_detector_feature" "rds_login_events" {
  detector_id = aws_guardduty_detector.this.id
  name        = "RDS_LOGIN_EVENTS"
  status      = "DISABLED"
}

resource "aws_guardduty_detector_feature" "lambda_network_logs" {
  detector_id = aws_guardduty_detector.this.id
  name        = "LAMBDA_NETWORK_LOGS"
  status      = "DISABLED"
}

resource "aws_cloudwatch_event_rule" "guardduty_findings" {
  name = "${var.team_name}-guardduty-to-kinesis"
  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
  })
}

resource "aws_cloudwatch_event_target" "guardduty_to_kinesis" {
  rule     = aws_cloudwatch_event_rule.guardduty_findings.name
  arn      = aws_kinesis_stream.log_stream.arn
  role_arn = aws_iam_role.eventbridge_to_kinesis.arn
}

resource "aws_cloudwatch_event_rule" "backup_job_state_change" {
  name = "${var.team_name}-backup-job-state-change"
  event_pattern = jsonencode({
    source      = ["aws.backup"]
    detail-type = ["Backup Job State Change"]
  })
}

resource "aws_cloudwatch_event_target" "backup_to_kinesis" {
  rule     = aws_cloudwatch_event_rule.backup_job_state_change.name
  arn      = aws_kinesis_stream.log_stream.arn
  role_arn = aws_iam_role.eventbridge_to_kinesis.arn
}

resource "aws_cloudwatch_log_group" "vpc_flow" {
  name                        = "/aws/vpc/${var.team_name}-vpc-flow"
  retention_in_days           = var.log_pipeline.log_group.retention_in_days
  log_group_class             = var.log_pipeline.log_group.log_group_class
  kms_key_id                  = data.aws_kms_key.log_key.arn
  deletion_protection_enabled = var.log_pipeline.log_group.deletion_protection_enabled
}

resource "aws_iam_role" "vpc_flow_log" {
  name = "${var.team_name}-vpc-flow-log-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "vpc_flow_log" {
  role = aws_iam_role.vpc_flow_log.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ]
      Resource = "${aws_cloudwatch_log_group.vpc_flow.arn}:*"
    }]
  })
}

resource "aws_flow_log" "vpc_flow" {
  vpc_id               = var.vpc_id
  log_destination_type = "cloud-watch-logs"
  log_destination      = aws_cloudwatch_log_group.vpc_flow.arn
  iam_role_arn         = aws_iam_role.vpc_flow_log.arn
  traffic_type         = "ALL"
}

resource "aws_s3_bucket" "cloudtrail" {
  bucket        = "${var.team_name}-cloudtrail-${data.aws_caller_identity.current.account_id}"
  force_destroy = var.log_pipeline.cloudtrail.force_destroy
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = data.aws_kms_key.log_key.arn
    }
  }
}

resource "aws_s3_bucket_public_access_block" "cloudtrail" {
  bucket                  = aws_s3_bucket.cloudtrail.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AWSCloudTrailAclCheck"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:GetBucketAcl"
        Resource  = aws_s3_bucket.cloudtrail.arn
      },
      {
        Sid       = "AWSCloudTrailWrite"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.cloudtrail.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "cloudtrail" {
  name                        = "/aws/cloudtrail/${var.team_name}"
  retention_in_days           = var.log_pipeline.log_group.retention_in_days
  log_group_class             = var.log_pipeline.log_group.log_group_class
  kms_key_id                  = data.aws_kms_key.log_key.arn
  deletion_protection_enabled = var.log_pipeline.log_group.deletion_protection_enabled
}

resource "aws_iam_role" "cloudtrail_to_cwl" {
  name = "${var.team_name}-cloudtrail-to-cwl-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "cloudtrail.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "cloudtrail_to_cwl" {
  role = aws_iam_role.cloudtrail_to_cwl.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
      Resource = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
    }]
  })
}

resource "aws_cloudtrail" "this" {
  name                          = "${var.team_name}-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail.id
  cloud_watch_logs_group_arn    = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
  cloud_watch_logs_role_arn     = aws_iam_role.cloudtrail_to_cwl.arn
  include_global_service_events = var.log_pipeline.cloudtrail.include_global_service_events
  is_multi_region_trail         = var.log_pipeline.cloudtrail.is_multi_region_trail
  enable_log_file_validation    = var.log_pipeline.cloudtrail.enable_log_file_validation
  kms_key_id                    = data.aws_kms_key.log_key.arn

  depends_on = [
    aws_s3_bucket_policy.cloudtrail,
    aws_iam_role_policy.cloudtrail_to_cwl,
  ]
}

#kinesis <- secrity zone logstash
data "aws_iam_user" "logstash_kinesis_consumer" {
  user_name = "iac01-logstash-kinesis-consumer"
}

resource "aws_iam_user_policy" "logstash_kinesis_consumer" {
  name = "${var.team_name}-logstash-kinesis-consumer-policy"
  user = data.aws_iam_user.logstash_kinesis_consumer.user_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "KinesisConsume"
        Effect = "Allow"
        Action = [
          "kinesis:GetRecords", "kinesis:GetShardIterator", "kinesis:DescribeStream", "kinesis:DescribeStreamSummary", "kinesis:ListShards"
        ]
        Resource = aws_kinesis_stream.log_stream.arn
      },
      {
        Sid      = "KMSDecrypt"
        Effect   = "Allow"
        Action   = ["kms:Decrypt"]
        Resource = data.aws_kms_key.log_key.arn
      },
      {
        Sid    = "KCLDynamoDBLease"
        Effect = "Allow"
        Action = [
          "dynamodb:CreateTable", "dynamodb:DescribeTable", "dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:DeleteItem", "dynamodb:Scan", "dynamodb:Query"
        ]
        Resource = "arn:aws:dynamodb:${var.region}:${data.aws_caller_identity.current.account_id}:table/${var.team_name}-logstash-kcl"
      },
      {
        Sid      = "KCLCloudWatchMetrics"
        Effect   = "Allow"
        Action   = ["cloudwatch:PutMetricData"]
        Resource = "*"
      }
    ]
  })
}

# security zone이 kinesis 의 dns이름 조회 가능하게 설정 
resource "aws_route53_resolver_endpoint" "inbound" {
  name      = "${var.team_name}-resolver-inbound"
  direction = "INBOUND"

  security_group_ids = [var.sg_map["resolver_inbound"]]

  ip_address {
    subnet_id = var.endpoint_subnet_ids[0]
    ip        = "10.12.16.250" # pinned so it survives destroy/apply cycles without touching log1 named.conf
  }
  ip_address {
    subnet_id = var.endpoint_subnet_ids[1]
    ip        = "10.12.17.250" # pinned, same reason
  }
}

# DynamoDB는 terraform destroy해도 삭제가 되지 않음. 매번 삭제해야함
# 그래서 destroy될 때마다 생성된 테이블 삭제해주는 provisioner
resource "null_resource" "cleanup_kcl_lease_table" {
  triggers = {
    table_name = "${var.team_name}-logstash-kcl"
    region     = var.region
  }

  provisioner "local-exec" {
    when    = destroy
    command = "aws dynamodb delete-table --region ${self.triggers.region} --table-name ${self.triggers.table_name} || true"
  }
}

# resolver_ip 고정해둠. eks에서 사용하지 못하도록 고정
resource "aws_ec2_subnet_cidr_reservation" "resolver_ip_0" {
  subnet_id        = var.endpoint_subnet_ids[0]
  cidr_block       = "10.12.16.250/32"
  reservation_type = "explicit"
}

resource "aws_ec2_subnet_cidr_reservation" "resolver_ip_1" {
  subnet_id        = var.endpoint_subnet_ids[1]
  cidr_block       = "10.12.17.250/32"
  reservation_type = "explicit"
}

# cloudwatch log -> logstash 폴링용도의 vpc endpoint 추가 
# cloudwatch에서 kinesis로 우회하면 gzip데이터가 깨지기 떄문에, 
# kinesis로 우회하지 않고 직접 cloudwatch에서 가져오는 방식사용
# (waf/rds/cache)
resource "aws_vpc_endpoint" "logs" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.region}.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.endpoint_subnet_ids
  security_group_ids  = [var.sg_map["log_pipeline"]]
  private_dns_enabled = true
}

resource "aws_iam_user_policy" "logstash_cloudwatch_direct_read" {
  name = "${var.team_name}-logstash-cloudwatch-direct-read-policy"
  user = data.aws_iam_user.logstash_kinesis_consumer.user_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchLogsDirectRead"
        Effect = "Allow"
        Action = [
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:GetLogEvents",
          "logs:FilterLogEvents"
        ]
        Resource = [
          "arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:aws-waf-logs-${var.team_name}:*",
          "arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/rds/instance/database-primary/error:*",
          "arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/rds/instance/database-primary/slowquery:*",
          "arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/elasticache/cache-db-${var.team_name}/engine-log:*",
          "arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/elasticache/cache-db-${var.team_name}/slow-log:*",
          "arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/elasticache/cache-sse-${var.team_name}/engine-log:*",
          "arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/elasticache/cache-sse-${var.team_name}/slow-log:*"
        ]
      }
    ]
  })
}
