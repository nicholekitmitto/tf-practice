/*=== VPC ===*/
resource "aws_vpc" "wp_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "wp_vpc"
  }
}

/*=== Subnets ===*/
resource "aws_subnet" "public_sub" {
  vpc_id                  = aws_vpc.wp_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "public_sub"
  }
}

resource "aws_subnet" "private_sub" {
  vpc_id                  = aws_vpc.wp_vpc.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = false

  tags = {
    Name = "private_sub"
  }
}

/*=== ENI ===*/
resource "aws_network_interface" "wp_eni" {
  subnet_id   = aws_subnet.private_sub.id
  private_ips = ["10.0.0.50"]

  attachment {
    instance     = aws_instance.wp_instance.id
    device_index = 1
  }

  tags = {
    Name = "private_network_interface"
  }
}

output "wp_eni" {
  value = aws_network_interface.wp_eni.id
}
/*=== NAT === */
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_network_interface.wp_eni.id
  subnet_id     = aws_subnet.public_sub.id

  tags = {
    Name = "pub_nat"
  }
}

/*=== IGW ===*/
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.wp_vpc.id

  tags = {
    Name = "wp_igw"
  }
}


/*== Route Tables ===*/
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.wp_vpc.id

  tags = {
    Name = "public_rt"
  }
}

resource "aws_route" "igw_route" {
  route_table_id         = aws_route_table.public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public_sub.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.wp_vpc.id

  tags = {
    Name = "private_rt"
  }
}

resource "aws_route" "nat_route" {
  route_table_id         = aws_route_table.private_rt.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat.id
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private_sub.id
  route_table_id = aws_route_table.private_rt.id
}


/*=== Instance ===*/
data "aws_ami" "amazon-linux-2" {
  most_recent = true

  filter {
    name   = "owner-alias"
    values = ["amazon"]
  }

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm*"]
  }
}

resource "aws_instance" "wp_instance" {
  ami           = data.aws_ami.amazon-linux-2.id
  instance_type = "t3.micro"

  network_interface {
    network_interface_id = aws_network_interface.wp_eni.id
    device_index         = 0
  }

  tags = {
    Name = "wp_instance"
  }
}

output "wp_instance" {
  value = aws_instance.wp_instance.id
}
