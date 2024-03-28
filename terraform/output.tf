output "CONFIG" {
  value = <<EOF
export REST_BASE_URL=http://${aws_lb.internal.dns_name}:3000/publish
export SSE_BASE_URL=http://${aws_lb.external.dns_name}:4000/sse
EOF
}
