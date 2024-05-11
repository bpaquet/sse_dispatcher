locals {
  user_data = <<-EOF
#!/bin/bash -e

yum install -y ncurses-compat-libs git jq
wget https://binaries2.erlang-solutions.com/centos/7/esl-erlang_26.2.1_1~centos~7_x86_64.rpm -O /tmp/esl-erlang_26.2.1_1~centos~7_x86_64.rpm
rpm -ivh /tmp/esl-erlang_26.2.1_1~centos~7_x86_64.rpm

wget https://github.com/elixir-lang/elixir/releases/download/v1.16.2/elixir-otp-26.zip -O /tmp/elixir-otp-26.zip
mkdir /opt/elixir
cd /opt/elixir
unzip /tmp/elixir-otp-26.zip

export PATH=/opt/elixir/bin:$PATH
export ELIXIR_ERL_OPTIONS="+fnu"
export HOME=/opt/home

mkdir $HOME

cd /opt
git clone https://github.com/bpaquet/sse_dispatcher
cd sse_dispatcher
git checkout ${var.sse_dispatcher_revision}

mix local.hex --force
mix deps.get

MIX_ENV=prod mix release

ulimit -n 1000000

_build/prod/rel/sse_dispatcher/bin/sse_dispatcher daemon

aws secretsmanager get-secret-value --region="${var.region}" --secret-id=${var.dd_secret} | jq -r .SecretString > /tmp/secret

DD_API_KEY="$(cat /tmp/secret)" DD_HOST_TAGS="${var.dd_tags}" bash -c "$(curl -L https://s3.amazonaws.com/dd-agent/scripts/install_script_agent7.sh)"

echo "instances:
  - prometheus_url: http://localhost:3000/metrics
    namespace: sse_dispatcher
    metrics:
    - '*'
" >> /etc/datadog-agent/conf.d/prometheus.d/conf.yaml
service datadog-agent restart
EOF
}

resource "aws_iam_instance_profile" "sse_dispatcher" {
  name = "${var.prefix}-sse-dispatcher"
  role = aws_iam_role.sse_dispatcher.name
}

resource "aws_iam_role" "sse_dispatcher" {
  name = "${var.prefix}-sse-dispatcher"
  path = "/"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
               "Service": "ec2.amazonaws.com"
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "sse_dispatcher_ssm" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.sse_dispatcher.name
}

resource "aws_iam_role_policy_attachment" "sse_dispatcher_policy" {
  policy_arn = aws_iam_policy.sse_dispatcher_policy.arn
  role       = aws_iam_role.sse_dispatcher.name
}

resource "aws_iam_policy" "sse_dispatcher_policy" {
  name = "${var.prefix}-sse-dispatcher-policy"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [

    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue"
      ],
      "Resource": "${var.dd_secret}"
    }
  ]
}
EOF
}

resource "aws_launch_template" "sse_dispatcher" {
  name = "${var.prefix}-sse-dispatcher"

  ebs_optimized = true

  iam_instance_profile {
    name = aws_iam_instance_profile.sse_dispatcher.name
  }

  image_id = data.aws_ami.ami-x86.id

  instance_initiated_shutdown_behavior = "terminate"

  instance_type = var.instance_type

  monitoring {
    enabled = true
  }

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.sse_dispatcher.id]
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.prefix}-sse-dispatcher"
    }
  }

  user_data = base64encode(local.user_data)
}

resource "aws_security_group" "sse_dispatcher" {
  name   = "${var.prefix}-sse-dispatcher"
  vpc_id = data.aws_subnet.first_private.vpc_id
}

resource "aws_security_group_rule" "sse_dispatcher_outbound" {
  type              = "egress"
  from_port         = 0
  to_port           = 65535
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.sse_dispatcher.id
}

resource "aws_security_group_rule" "sse_dispatcher_inbound_internal_3000" {
  type      = "ingress"
  from_port = 3000
  to_port   = 3000
  protocol  = "tcp"
  # cidr_blocks       = ["0.0.0.0/0"]
  source_security_group_id = aws_security_group.internal_lb.id
  security_group_id        = aws_security_group.sse_dispatcher.id
}

resource "aws_security_group_rule" "sse_dispatcher_inbound_external_3000" {
  type      = "ingress"
  from_port = 3000
  to_port   = 3000
  protocol  = "tcp"
  # cidr_blocks       = ["0.0.0.0/0"]
  source_security_group_id = aws_security_group.external_lb.id
  security_group_id        = aws_security_group.sse_dispatcher.id
}


resource "aws_security_group_rule" "sse_dispatcher_inbound_4000" {
  type      = "ingress"
  from_port = 4000
  to_port   = 4000
  protocol  = "tcp"
  # cidr_blocks       = ["0.0.0.0/0"]
  source_security_group_id = aws_security_group.external_lb.id
  security_group_id        = aws_security_group.sse_dispatcher.id
}

resource "aws_autoscaling_group" "sse_dispatcher" {
  name             = "${var.prefix}-sse-dispatcher"
  desired_capacity = var.desired_capacity
  max_size         = var.max_size
  min_size         = var.min_size

  vpc_zone_identifier = var.private_subnets

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }

  launch_template {
    id      = aws_launch_template.sse_dispatcher.id
    version = aws_launch_template.sse_dispatcher.latest_version
  }

  health_check_type = "ELB"

  target_group_arns = [
    aws_lb_target_group.external.arn,
    aws_lb_target_group.internal.arn
  ]
}