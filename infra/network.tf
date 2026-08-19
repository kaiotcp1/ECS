locals {
  availability_zones = slice(data.aws_availability_zones.available.names, 0, 2)

  public_subnets = {
    a = {
      availability_zone = local.availability_zones[0]
      cidr_block        = "10.0.1.0/24"
    }
    b = {
      availability_zone = local.availability_zones[1]
      cidr_block        = "10.0.2.0/24"
    }
  }

  private_subnets = {
    a = {
      availability_zone = local.availability_zones[0]
      cidr_block        = "10.0.11.0/24"
    }
    b = {
      availability_zone = local.availability_zones[1]
      cidr_block        = "10.0.12.0/24"
    }
  }
}

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.name_prefix}-vpc"
  }
}

resource "aws_default_route_table" "main" {
  default_route_table_id = aws_vpc.main.default_route_table_id

  tags = {
    Name = "${var.name_prefix}-main-rt"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.name_prefix}-igw"
  }
}

resource "aws_subnet" "public" {
  for_each = local.public_subnets

  vpc_id                  = aws_vpc.main.id
  availability_zone       = each.value.availability_zone
  cidr_block              = each.value.cidr_block
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.name_prefix}-public-${each.key}"
    Tier = "public"
  }
}

resource "aws_subnet" "private" {
  for_each = local.private_subnets

  vpc_id                  = aws_vpc.main.id
  availability_zone       = each.value.availability_zone
  cidr_block              = each.value.cidr_block
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.name_prefix}-private-${each.key}"
    Tier = "private"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.name_prefix}-public-rt"
  }
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

resource "aws_route_table_association" "public" {
  for_each = local.public_subnets

  subnet_id      = aws_subnet.public[each.key].id
  route_table_id = aws_route_table.public.id
}

# O NAT regional em modo automatico acompanha as AZs que possuem workloads.
# A AWS cria e remove os Elastic IPs conforme as tarefas aparecem e desaparecem.
resource "aws_nat_gateway" "main" {
  vpc_id            = aws_vpc.main.id
  availability_mode = "regional"
  connectivity_type = "public"

  depends_on = [aws_internet_gateway.main]

  tags = {
    Name = "${var.name_prefix}-nat-regional"
  }
}

resource "aws_route_table" "private" {
  for_each = local.private_subnets

  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.name_prefix}-private-${each.key}-rt"
  }
}

resource "aws_route" "private_internet" {
  for_each = local.private_subnets

  route_table_id         = aws_route_table.private[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main.id
}

resource "aws_route_table_association" "private" {
  for_each = local.private_subnets

  subnet_id      = aws_subnet.private[each.key].id
  route_table_id = aws_route_table.private[each.key].id
}
