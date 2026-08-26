data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_vpc" "existing" {
  id = var.vpc_id
}

data "aws_internet_gateway" "existing" {
  filter {
    name   = "attachment.vpc-id"
    values = [var.vpc_id]
  }
}

locals {
  availability_zones = slice(data.aws_availability_zones.available.names, 0, 2)

  public_subnet_cidrs = {
    az1 = "10.0.0.0/24"
    az2 = "10.0.1.0/24"
  }

  cache_subnet_cidrs = {
    az1 = "10.0.20.0/24"
    az2 = "10.0.21.0/24"
  }
}

check "vpc_cidr" {
  assert {
    condition     = data.aws_vpc.existing.cidr_block == "10.0.0.0/16"
    error_message = "The managed subnet layout requires the existing VPC to use 10.0.0.0/16."
  }
}

resource "aws_subnet" "public" {
  for_each = local.public_subnet_cidrs

  vpc_id                  = var.vpc_id
  availability_zone       = local.availability_zones[index(keys(local.public_subnet_cidrs), each.key)]
  cidr_block              = each.value
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-${each.key}"
    Tier = "public"
  }
}

resource "aws_subnet" "cache" {
  for_each = local.cache_subnet_cidrs

  vpc_id                  = var.vpc_id
  availability_zone       = local.availability_zones[index(keys(local.cache_subnet_cidrs), each.key)]
  cidr_block              = each.value
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.project_name}-cache-${each.key}"
    Tier = "private"
  }
}

resource "aws_route_table" "public" {
  vpc_id = var.vpc_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = data.aws_internet_gateway.existing.id
  }

  tags = {
    Name = "${var.project_name}-public"
    Tier = "public"
  }
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}
