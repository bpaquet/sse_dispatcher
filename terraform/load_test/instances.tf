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
cd sse_dispatcher/load_test
git checkout ${var.version_override != "" ? var.version_override : data.terraform_remote_state.local.outputs.sse_dispatcher_revision}

mix local.hex --force
mix deps.get

MIX_ENV=prod mix release

ulimit -n 1000000

${data.terraform_remote_state.local.outputs.config}

export NB_USER=${var.nb_users}
export RELEASE_TMP=/tmp/

_build/prod/rel/load_test/bin/load_test daemon

aws secretsmanager get-secret-value --region="${var.region}" --secret-id=${data.terraform_remote_state.local.outputs.dd_secret} | jq -r .SecretString > /tmp/secret

DD_API_KEY="$(cat /tmp/secret)" DD_HOST_TAGS="${data.terraform_remote_state.local.outputs.dd_tags}" bash -c "$(curl -L https://s3.amazonaws.com/dd-agent/scripts/install_script_agent7.sh)"

echo "instances:
  - prometheus_url: http://localhost:2999/metrics
    namespace: sse_dispatcher_load_test
    metrics:
    - '*'
" >> /etc/datadog-agent/conf.d/prometheus.d/conf.yaml
service datadog-agent restart
EOF
}

resource "aws_iam_instance_profile" "load_test_sse_dispatcher" {
  name = "${data.terraform_remote_state.local.outputs.prefix}-load-test-sse-dispatcher"
  role = aws_iam_role.load_test_sse_dispatcher.name
}

resource "aws_iam_role" "load_test_sse_dispatcher" {
  name = "${data.terraform_remote_state.local.outputs.prefix}-load-test-sse-dispatcher"
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

resource "aws_iam_role_policy_attachment" "load_test_sse_dispatcher_ssm" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.load_test_sse_dispatcher.name
}

resource "aws_iam_role_policy_attachment" "load_test_sse_dispatcher_policy" {
  policy_arn = aws_iam_policy.load_test_sse_dispatcher_policy.arn
  role       = aws_iam_role.load_test_sse_dispatcher.name
}

resource "aws_iam_policy" "load_test_sse_dispatcher_policy" {
  name = "${data.terraform_remote_state.local.outputs.prefix}-load-test-sse-dispatcher-policy"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [

    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue"
      ],
      "Resource": "${data.terraform_remote_state.local.outputs.dd_secret}"
    }
  ]
}
EOF
}

resource "aws_launch_template" "load_test_sse_dispatcher" {
  name = "${data.terraform_remote_state.local.outputs.prefix}-load-test-sse-dispatcher"

  ebs_optimized = true

  iam_instance_profile {
    name = aws_iam_instance_profile.load_test_sse_dispatcher.name
  }

  image_id = data.terraform_remote_state.local.outputs.ami_x86

  instance_initiated_shutdown_behavior = "terminate"

  instance_type = var.instance_type

  monitoring {
    enabled = true
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.load_test_sse_dispatcher.id]
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${data.terraform_remote_state.local.outputs.prefix}-load-test-sse-dispatcher"
    }
  }

  user_data = base64encode(local.user_data)
}

resource "aws_security_group" "load_test_sse_dispatcher" {
  name   = "${data.terraform_remote_state.local.outputs.prefix}-load-test-sse-dispatcher"
  vpc_id = data.aws_subnet.first_public.vpc_id
}

resource "aws_security_group_rule" "load_test_sse_dispatcher_outbound" {
  type              = "egress"
  from_port         = 0
  to_port           = 65535
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.load_test_sse_dispatcher.id
}

resource "aws_autoscaling_group" "load_test_sse_dispatcher" {
  name             = "${data.terraform_remote_state.local.outputs.prefix}-load-test-sse-dispatcher"
  desired_capacity = var.desired_capacity
  max_size         = var.max_size
  min_size         = var.min_size

  vpc_zone_identifier = data.terraform_remote_state.local.outputs.public_subnets

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }

  launch_template {
    id      = aws_launch_template.load_test_sse_dispatcher.id
    version = aws_launch_template.load_test_sse_dispatcher.latest_version
  }

  health_check_type = "EC2"
}