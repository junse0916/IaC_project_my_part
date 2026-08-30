variable "vpc_id" {
  description = "AWS VPC의 ID"
  type        = string
}

variable "team_name" {
  description = "팀 이름"
  type        = string
}

variable "sg_map" {
  description = "보안 그룹 map"
  type = map(object(
    {
      description = string
      ingress_rules = map(object(
        {
          protocol        = string
          from_port       = number
          to_port         = number
          cidr_blocks     = optional(list(string))
          prefix_list_ids = optional(list(string))
          source_sg       = optional(string)
        }
      ))
      egress_rules = map(object(
        {
          protocol        = string
          from_port       = number
          to_port         = number
          cidr_blocks     = optional(list(string))
          prefix_list_ids = optional(list(string))
          source_sg       = optional(string)
        }
      ))
    }
  ))
}

## 룰 평탄화
locals {
  ingress_rules_flat = merge([
    for sg_name, sg in var.sg_map : {
      for rule_name, rule in sg.ingress_rules :
      "${sg_name}.${rule_name}" => merge(rule, { sg_name = sg_name })
    }
  ]...)

  egress_rules_flat = merge([
    for sg_name, sg in var.sg_map : {
      for rule_name, rule in sg.egress_rules :
      "${sg_name}.${rule_name}" => merge(rule, { sg_name = sg_name })
    }
  ]...)
}
