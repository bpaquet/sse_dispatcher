resource "aws_security_group" "external_lb" {
  name   = "${var.prefix}-sse-dispatcher-external-lb"
  vpc_id = data.aws_subnet.first_public.vpc_id
}

resource "aws_security_group_rule" "external_lb_inbound_https" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.external_lb.id
}

resource "aws_security_group_rule" "external_lb_outbound_4000" {
  type              = "egress"
  from_port         = 4000
  to_port           = 4000
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.external_lb.id
}

resource "aws_security_group_rule" "external_lb_outbound_3000" {
  type              = "egress"
  from_port         = 3000
  to_port           = 3000
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.external_lb.id
}


resource "aws_lb" "external" {
  name               = "${var.prefix}-sse-dispatcher-external-lb"
  internal           = false
  load_balancer_type = "network"

  subnets         = var.public_subnets
  security_groups = [aws_security_group.external_lb.id]

  enable_cross_zone_load_balancing = false

  tags = {
    Name = "${var.prefix}-sse-dispatcher-external-lb"
  }
}

resource "aws_lb_listener" "external-tls" {
  load_balancer_arn = aws_lb.external.arn
  port              = "443"
  protocol          = var.acm_domain != "" ? "TLS" : "TCP"
  certificate_arn   = var.acm_domain != "" ? data.aws_acm_certificate.certificate[0].arn : null

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.external.arn
  }
}

resource "aws_lb_target_group" "external" {
  name     = "${var.prefix}-sse-dispatcher-external"
  port     = 4000
  protocol = "TCP"
  vpc_id   = data.aws_subnet.first_public.vpc_id

  health_check {
    path     = "/cluster_size_above/${var.health_check_min_cluster_size}"
    port     = 3000
    protocol = "HTTP"
    interval = 10
  }
}
