## vpc 생성
resource "aws_vpc" "main" {
  cidr_block           = var.cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "${var.region_name}-vpc-main"
  }
}

## public 서브넷 생성 
resource "aws_subnet" "publics" {
  count = var.count_of_public_subnets

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = true
  tags = {
    Name                                        = "public-subnet-${var.team_name}-${count.index + 1}"
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

## private 서브넷 생성 (eks, rds로 분류)
resource "aws_subnet" "privates_eks" {
  count = var.count_of_private_subnets

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_eks_subnet_cidrs[count.index]
  availability_zone = var.azs[count.index]
  tags = {
    Name                                        = "private-subnet-eks-${var.team_name}-${count.index + 1}"
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

resource "aws_subnet" "privates_rds" {
  count = var.count_of_private_subnets

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_rds_subnet_cidrs[count.index]
  availability_zone = var.azs[count.index]
  tags = {
    Name = "private-subnet-rds-${var.team_name}-${count.index + 1}"
  }
}

## internet gateway 생성 
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${var.region_name}-igw-main-${var.team_name}"
  }
}

## elastic ip 설정
resource "aws_eip" "nat_ips" {
  count  = var.create_nat_gw ? var.count_of_az : 0
  domain = "vpc"
  tags = {
    Name = "nat-eip-${var.team_name}-${count.index + 1}"
  }
}

## nat gateway 생성 시, yaml파일에서 create_nat_gw true로 바꾸고 실행 
resource "aws_nat_gateway" "private_nat_gws" {
  count = var.create_nat_gw ? var.count_of_az : 0

  allocation_id = aws_eip.nat_ips[count.index].id
  subnet_id     = aws_subnet.publics[count.index].id
  tags = {
    Name = "nat-gw-${var.team_name}-${count.index + 1}"
  }
}

## public route table 생성 및 public 서브넷 연결 
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = {
    Name = "route-public-${var.team_name}"
  }

  # Hybrid Pod CIDR routes are managed as standalone aws_route resources by
  # the VPN module after the TGW exists. Keep the inline IGW default route
  # without having this resource remove those externally managed routes.
  lifecycle {
    ignore_changes = [route]
  }
}

resource "aws_route_table_association" "public" {
  count = var.count_of_public_subnets

  route_table_id = aws_route_table.public.id
  subnet_id      = aws_subnet.publics[count.index].id
}

## az별로 나누어서 private route table 생성 및 private 서브넷 연결
resource "aws_route_table" "with_nat_privates" {
  count  = var.create_nat_gw ? var.count_of_az : 0
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.private_nat_gws[count.index].id
  }
  tags = {
    Name = "route-private-${var.team_name}-${count.index + 1}"
  }

  lifecycle {
    ignore_changes = [route]
  }
}

resource "aws_route_table" "without_nat_privates" {
  count  = var.create_nat_gw ? 0 : var.count_of_az
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "route-private-${var.team_name}-${count.index + 1}"
  }
}

resource "aws_route_table_association" "private_eks" {
  count = var.count_of_private_subnets

  route_table_id = (
    var.create_nat_gw
    ? aws_route_table.with_nat_privates[count.index].id
    : aws_route_table.without_nat_privates[count.index].id
  )
  subnet_id = aws_subnet.privates_eks[count.index].id
}

resource "aws_route_table_association" "private_rds" {
  count = var.count_of_private_subnets

  route_table_id = (
    var.create_nat_gw
    ? aws_route_table.with_nat_privates[count.index].id
    : aws_route_table.without_nat_privates[count.index].id
  )
  subnet_id = aws_subnet.privates_rds[count.index].id
}

