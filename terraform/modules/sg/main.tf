## 보안그룹 생성 - yaml파일에서 map으로 설정함. 룰 껍데기만 
resource "aws_security_group" "sg_map" {
  for_each = var.sg_map

  vpc_id      = var.vpc_id
  name        = "fw-${each.key}"
  description = each.value.description
  tags = {
    Name = "fw-${each.key}-${var.team_name}"
  }
}

## ingress 룰 - cidr_blocks 또는 source_sg 이름 참조
resource "aws_security_group_rule" "ingress" {
  for_each = local.ingress_rules_flat

  type                     = "ingress"
  security_group_id        = aws_security_group.sg_map[each.value.sg_name].id
  protocol                 = each.value.protocol
  from_port                = each.value.from_port
  to_port                  = each.value.to_port
  cidr_blocks              = each.value.cidr_blocks
  prefix_list_ids          = try(each.value.prefix_list_ids, null)
  source_security_group_id = each.value.source_sg != null ? aws_security_group.sg_map[each.value.source_sg].id : null

}

## egress 룰 - cidr_blocks 또는 source_sg 이름 참조
resource "aws_security_group_rule" "egress" {
  for_each = local.egress_rules_flat

  type                     = "egress"
  security_group_id        = aws_security_group.sg_map[each.value.sg_name].id
  protocol                 = each.value.protocol
  from_port                = each.value.from_port
  to_port                  = each.value.to_port
  cidr_blocks              = each.value.cidr_blocks
  prefix_list_ids          = try(each.value.prefix_list_ids, null)
  source_security_group_id = each.value.source_sg != null ? aws_security_group.sg_map[each.value.source_sg].id : null

}
