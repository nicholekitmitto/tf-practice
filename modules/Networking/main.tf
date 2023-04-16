/*=== VPC ===*/

resource "aws_vpc" "wp_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "wp_vpc"
  }
}

/*=== Subnets ===*/
resource "aws_subnet" "public_sub" {
  vpc_id     = aws_vpc.wp_vpc.id
  cidr_block = "10.0.1.0/16"
  map_public_ip_on_launch = true

  tags = {
    Name = "public_sub"
  }
}

resource "aws_subnet" "private_sub" {
  vpc_id     = aws_vpc.wp_vpc.id
  cidr_block = "10.0.2.0/16"
  map_public_ip_on_launch = false

  tags = {
    Name = "private_sub"
  }
}

/*=== IGW ===*/

