/*=== VPC ===*/
resource "aws_vpc" "wp_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "wp_vpc"
  }
}

/*=== IGW ===*/
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.wp_vpc.id

  tags = {
    Name = "wp_igw"
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
  subnet_id = aws_subnet.private_sub.id

  tags = {
    Name = "private_network_interface"
  }
}

resource "aws_eip" "nat_eip" {
  vpc = true
}

/*=== NAT === */
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_sub.id

  tags = {
    Name = "pub_nat"
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

/*=== Security Group ===*/
resource "aws_security_group" "lb_sg" {
  name        = "lb_sg"
  description = "Allow public internet traffic"
  vpc_id      = aws_vpc.wp_vpc.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "http"
    cidr_blocks = [aws_vpc.wp_vpc.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "lb_sg"
  }
}

/*=== Load Balancer/TG ===*/
resource "aws_s3_bucket" "lb_logs" {
  bucket = "wp_lb_logs_bucket"
}

resource "aws_lb" "wp_lb" {
  name               = "wp_lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb_sg.id]
  subnets            = aws_subnet.public_sub

  access_logs {
    bucket  = aws_s3_bucket.lb_logs.id
    prefix  = "wp-lb"
    enabled = true
  }
}

resource "aws_lb_target_group" "wp_lb_tg" {
  name     = "wp_lb_tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.wp_vpc.id

}

resource "aws_lb_target_group_attachment" "wp_lb_attach" {
  target_group_arn = aws_lb_target_group.wp_lb_tg.arn
  target_id        = aws_instance.wp_instance.id
  port             = 80
}
