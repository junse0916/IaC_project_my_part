locals {
  certificate_arn = trimspace(var.certificate_arn)
  https_enabled   = var.https_enabled != null ? var.https_enabled : local.certificate_arn != ""
}

data "aws_route53_zone" "public" {
  name         = trimsuffix(var.hosted_zone_name, ".")
  private_zone = false
}

resource "aws_lb" "this" {
  name                       = var.name
  internal                   = var.internal
  load_balancer_type         = "application"
  security_groups            = var.security_group_ids
  subnets                    = var.subnet_ids
  ip_address_type            = var.ip_address_type
  drop_invalid_header_fields = true
  desync_mitigation_mode     = "defensive"
  enable_deletion_protection = var.deletion_protection
  enable_http2               = true
  idle_timeout               = var.idle_timeout

  tags = merge(var.tags, {
    Name = var.name
  })
}

resource "aws_lb_target_group" "was" {
  name        = var.target_group_name
  port        = var.target_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  deregistration_delay = 30
  protocol_version     = "HTTP1"

  health_check {
    enabled             = true
    protocol            = "HTTP"
    path                = var.health_check_path
    matcher             = var.health_check_matcher
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = merge(var.tags, {
    Name = var.target_group_name
  })
}

# Before an ACM certificate is configured, HTTP returns a controlled 503.
# After certificate_arn is set, HTTP redirects viewers to HTTPS.
resource "aws_lb_listener" "http_without_https" {
  count = local.https_enabled ? 0 : 1

  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "HTTPS certificate is not configured"
      status_code  = "503"
    }
  }

  tags = var.tags
}

resource "aws_lb_listener" "http_redirect" {
  count = local.https_enabled ? 1 : 0

  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  tags = var.tags
}

resource "aws_lb_listener" "https" {
  count = local.https_enabled ? 1 : 0

  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  certificate_arn   = local.certificate_arn
  ssl_policy        = var.ssl_policy

  # The target group intentionally has no attachments. A Kubernetes
  # TargetGroupBinding will register WAS pod IPs in a later deployment.
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.was.arn
  }

  tags = var.tags
}

resource "aws_route53_record" "origin" {
  zone_id = data.aws_route53_zone.public.zone_id
  name    = var.origin_domain_name
  type    = "A"

  alias {
    name                   = aws_lb.this.dns_name
    zone_id                = aws_lb.this.zone_id
    evaluate_target_health = false
  }
}
