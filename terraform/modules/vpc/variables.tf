variable "region" {
  description = "AWS 리전 코드"
  type        = string
}

variable "region_name" {
  description = "AWS 리전 이름"
  type        = string
}

variable "team_name" {
  description = "팀 이름"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name for Kubernetes subnet discovery tags"
  type        = string
}

variable "cidr_block" {
  description = "AWS VPC 전체 CIDR 네트워크 대역"
  type        = string
}

variable "azs" {
  description = "사용할 가용영역"
  type        = list(string)
}

variable "count_of_public_subnets" {
  description = "공인 subnet의 수"
  type        = number
}

variable "count_of_private_subnets" {
  description = "사설 subnet의 수"
  type        = number
}

variable "public_subnet_cidrs" {
  description = "공인 subnet의 CIDR 목록"
  type        = list(string)
}

variable "private_eks_subnet_cidrs" {
  description = "사설 subnet(eks)의 CIDR 목록"
  type        = list(string)
}

variable "private_rds_subnet_cidrs" {
  description = "사설 subnet(eks)의 CIDR 목록"
  type        = list(string)
}

variable "count_of_az" {
  description = "vpc az의 개수"
  type        = number
}

variable "create_nat_gw" {
  description = "nat gateway 생성 여부"
  type        = bool
}
