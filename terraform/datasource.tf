data "aws_ami" "ami-arm" {
  filter {
    name   = "name"
    values = ["amzn2-ami-kernel-*-hvm-*arm*"]
  }

  most_recent = true
  owners      = ["137112412989"]
}

data "aws_ami" "ami-x86" {
  filter {
    name   = "name"
    values = ["amzn2-ami-kernel-*-hvm-*x86*"]
  }

  most_recent = true
  owners      = ["137112412989"]
}

data "aws_subnet" "first_private" {
  id = var.private_subnets[0]
}


data "aws_subnet" "first_public" {
  id = var.public_subnets[0]
}

data "aws_acm_certificate" "certificate" {
  count    = var.acm_domain != "" ? 1 : 0
  domain   = var.acm_domain
  statuses = ["ISSUED"]
}
