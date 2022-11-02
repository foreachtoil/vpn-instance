module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "= 3.16.0"
  name = "${var.app_name}_vpc"
  enable_dns_hostnames = true
  enable_dns_support = true
  cidr = var.cidr
}

resource "aws_subnet" "private_subnets" {
  count = 2
  cidr_block = cidrsubnet(var.cidr, 4, count.index) # var.cidr -> 10.0.0.0/20 --> 4 --> 10.0.0.0/20+4 /24, 0 o 1  --> 10.0.0.0/24, 10.0.1.0/24
  vpc_id = module.vpc.vpc_id
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = {
    "Name" = "${var.app_name}_private_subnet_${count.index}"
  }
}

resource "aws_subnet" "public_subnets" {
  count = 2
  cidr_block = cidrsubnet(var.cidr, 4, 2 + count.index) # var.cidr -> 10.0.0.0/20 --> 4 --> 10.0.0.0/20+4 /24, 2 o 3  --> 10.0.2.0/24, 10.0.3.0/24
  vpc_id = module.vpc.vpc_id
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = {
    "Name" = "${var.app_name}_public_subnet_${count.index}"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = module.vpc.vpc_id
}

resource "aws_eip" "nat" {
  depends_on = [aws_internet_gateway.main]
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id = aws_subnet.public_subnets.0.id
  depends_on = [aws_internet_gateway.main]
}

resource "aws_route_table" "public" {
  vpc_id = module.vpc.vpc_id
  route = [
    {
      cidr_block = "0.0.0.0/0"
      gateway_id = aws_internet_gateway.main.id
      core_network_arn = null
      destination_prefix_list_id = null
      egress_only_gateway_id = null
      nat_gateway_id = null
      instance_id = null
      ipv6_cidr_block = null
      network_interface_id = null
      transit_gateway_id = null
      vpc_endpoint_id = null
      vpc_peering_connection_id = null
      carrier_gateway_id = null
      local_gateway_id = null
    }
  ]
}

resource "aws_default_route_table" "private" {
  default_route_table_id = module.vpc.default_route_table_id
  route = [
    {
      cidr_block = "0.0.0.0/0"
      nat_gateway_id = aws_nat_gateway.main.id
      core_network_arn = null
      destination_prefix_list_id = null
      egress_only_gateway_id = null
      gateway_id = null
      instance_id = null
      ipv6_cidr_block = null
      network_interface_id = null
      transit_gateway_id = null
      vpc_endpoint_id = null
      vpc_peering_connection_id = null
      carrier_gateway_id = null
      local_gateway_id = null
    }
  ]
}

resource "aws_route_table_association" "public" {
  count = 2
  subnet_id = element(aws_subnet.public_subnets.*.id, count.index)
  route_table_id = aws_route_table.public.id
}