output "config" {
  value = <<EOF
export REST_BASE_URL="http://${aws_lb.internal.dns_name}:3000/publish"
EOF
}

output "dd_tags" {
  value = var.dd_tags
}

output "dd_secret" {
  value     = var.dd_secret
  sensitive = true
}

output "prefix" {
  value = var.prefix
}

output "private_subnets" {
  value = var.private_subnets
}

output "public_subnets" {
  value = var.public_subnets
}

output "ami_x86" {
  value = data.aws_ami.ami-x86.id
}