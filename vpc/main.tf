provider "aws" {
  region = "eu-central-1"
}

resource "aws_vpc" "testVPC" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support = true 
}

resource "aws_subnet" "web1SUBNET" {
  availability_zone = "eu-central-1a"
  cidr_block = "10.0.1.0/24"
  map_public_ip_on_launch = true
  vpc_id = aws_vpc.testVPC.id
  tags = {
      Name = "Subnet-webA"
  }
}

resource "aws_subnet" "web2SUBNET" {
  availability_zone = "eu-cental-1b"
  cidr_block = "10.0.2.0/24"
  map_public_ip_on_launch = true
  vpc_id = aws_vpc.testVPC.id
  tags = {
    Name = "Subnet-webB"
  }
}

resource "aws_subnet" "db1SUBNET" {
  availability_zone = "eu-cental-1a"
  cidr_block = "10.0.3.0/24"
  map_public_ip_on_launch = false
  vpc_id = aws_vpc.testVPC.id
  tags = {
      Name = "Subnet-dbA"
  }
}

resource "aws_subnet" "db2SUBNET" {
  availability_zone = "eu-cental-1b"
  cidr_block = "10.0.4.0/24"
  map_public_ip_on_launch = false
  vpc_id = aws_vpc.testVPC.id
  tags = {
   Name = "Subnet-dbB"
  }
}

resource "aws_internet_gateway" "inetGW" {
  vpc_id = aws_vpc.testVPC.id
  tags = {
      Name = "IGW-VPC-${var.name}"
  }
}

resource "aws_route_table" "eu-test" {
  vpc_id = aws_vpc.testVPC.id
  route {
      cidr_block = "0.0.0.0/0"
      gateway_id = aws_internet_gateway.inetGW.id
  }

  tags = {
      Name = "Route-Table-EU"
  }
}

resource "aws_route_table_association" "eu-west-1a-public" {
  subnet_id = aws_subnet.web1SUBNET.id
  route_table_id = aws_route_table.eu-test.id
}

resource "aws_route_table_association" "eu-west-1b-public" {
  subnet_id = aws_subnet.web2SUBNET.id
  route_table_id = aws_route_table.eu-test.id
}


resource "aws_route_table_association" "eu-west-1a-private" {
  subnet_id = aws_subnet.db1SUBNET.id
  route_table_id = aws_route_table.eu-test.id
}

resource "aws_route_table_association" "eu-west-1b-private" {
  subnet_id = aws_subnet.db2SUBNET.id
  route_table_id = aws_route_table.eu-test.id
}


