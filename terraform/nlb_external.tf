resource "aws_security_group" "external_lb" {
  name   = "${var.prefix}-sse-dispatcher-external-lb"
  vpc_id = data.aws_subnet.first_public.vpc_id
}

resource "aws_security_group_rule" "external_lb_inbound" {
  type              = "ingress"
  from_port         = 4000
  to_port           = 4000
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.external_lb.id
}

resource "aws_security_group_rule" "external_lb_outbound" {
  type              = "egress"
  from_port         = 4000
  to_port           = 4000
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

  enable_cross_zone_load_balancing = true

  tags = {
    Name = "${var.prefix}-sse-dispatcher-external-lb"
  }
}

resource "aws_lb_listener" "external" {
  load_balancer_arn = aws_lb.external.arn
  port              = "4000"
  protocol          = "TCP"

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
    path     = "/ping"
    port     = 4000
    protocol = "HTTP"
    interval = 10
  }
}
