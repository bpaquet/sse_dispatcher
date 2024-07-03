resource "aws_security_group" "internal_lb" {
  name   = "${var.prefix}-sse-dispatcher-internal-lb"
  vpc_id = data.aws_subnet.first_private.vpc_id
}

resource "aws_security_group_rule" "internal_lb_inbound" {
  type              = "ingress"
  from_port         = 3000
  to_port           = 3000
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.internal_lb.id
}

resource "aws_security_group_rule" "internal_lb_outbound" {
  type              = "egress"
  from_port         = 3000
  to_port           = 3000
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.internal_lb.id
}

resource "aws_lb" "internal" {
  name               = "${var.prefix}-sse-dispatcher-internal-lb"
  internal           = true
  load_balancer_type = "network"

  subnets         = var.private_subnets
  security_groups = [aws_security_group.internal_lb.id]

  enable_cross_zone_load_balancing = false

  tags = {
    Name = "${var.prefix}-sse-dispatcher-internal-lb"
  }
}

resource "aws_lb_listener" "internal" {
  load_balancer_arn = aws_lb.internal.arn
  port              = "3000"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.internal.arn
  }
}

resource "aws_lb_target_group" "internal" {
  name     = "${var.prefix}-sse-dispatcher-internal"
  port     = 3000
  protocol = "TCP"
  vpc_id   = data.aws_subnet.first_private.vpc_id

  health_check {
    path     = "/ping"
    port     = 3000
    protocol = "HTTP"
    interval = 10
  }
}
