output "sg_ids" {
  value = [
    for k, v in aws_security_group.sg_map :
    v.id
  ]
}

output "sg_map" {
  value = {
    for k, v in aws_security_group.sg_map :
    k => v.id
  }
}