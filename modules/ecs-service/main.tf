resource "aws_ecr_repository" "repository" {
  count = var.stage == "dev" ? 1 : 0
  name  = "${var.stage}-${var.name}"

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_cloudwatch_log_group" "container_log" {
  name              = "${var.stage}-${var.name}"
  retention_in_days = 14
}

locals {
  repository_urls = {
    for name, repository in aws_ecr_repository.repository : name => repository.repository_url
  }

  environment = {
    stage = var.stage

  }
  docker_tag = lookup({
    dev = "latest"
  }, var.stage)
}

resource "aws_ecs_task_definition" "task_definition" {
  family                   = "${var.stage}-${var.name}"
  execution_role_arn       = aws_iam_role.execution_role.arn
  task_role_arn            = aws_iam_role.task_role.arn
  memory                   = var.memory * 1024 * max(var.desired_count == null ? 0 : var.desired_count, 1) * 2
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]
  container_definitions = jsonencode([
    {
      name      = var.name
      image     = var.stage == "dev" ? "${aws_ecr_repository.repository.0.repository_url}" : ""
      essential = true
      memory    = var.memory * 1024
      portMappings = concat(var.port_mappings, [
        {
          containerPort = var.container_port
          hostPort      = var.container_port
          protocol      = "tcp"
        }
      ])
      environment = [
        for name, value in local.environment : {
          name  = name
          value = value
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.container_log.name
          "awslogs-stream-prefix" = "${var.stage}-${var.name}-logs"
          "awslogs-region"        = "eu-central-1"
        }
      }
      repository_credentials = null
    }
  ])

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }
}

resource "aws_service_discovery_private_dns_namespace" "namespace" {
  name        = "${var.name}-namespace"
  description = "Private DNS namespace for ${var.name}"
  vpc         = aws_vpc.main.id
}

resource "aws_service_discovery_service" "service" {
  name = var.name

  dns_config {
    namespace_id   = aws_service_discovery_private_dns_namespace.namespace.id
    routing_policy = "MULTIVALUE"

    dns_records {
      ttl  = 10
      type = "A"
    }
  }

  health_check_custom_config {
    failure_threshold = 5
  }

  lifecycle {
    ignore_changes = [health_check_custom_config[0].failure_threshold]
  }
}

resource "aws_ecs_cluster" "cluster" {
  name = "${var.name}-cluster"
}

resource "aws_ecs_service" "service" {
  name                              = var.name
  cluster                           = aws_ecs_cluster.cluster.id
  task_definition                   = aws_ecs_task_definition.task_definition.arn
  desired_count                     = var.desired_count
  enable_ecs_managed_tags           = false
  enable_execute_command            = true
  health_check_grace_period_seconds = 60
  launch_type                       = "EC2"
  propagate_tags                    = "TASK_DEFINITION"
  scheduling_strategy               = var.scheduling_strategy

  dynamic "load_balancer" {
    for_each = local.add_to_load_balancer ? ["load_balancer"] : []

    content {
      container_name   = var.name
      container_port   = var.container_port
      target_group_arn = aws_lb_target_group.target_group.0.arn
    }
  }

  network_configuration {
    subnets          = concat(aws_subnet.private[*].id, aws_subnet.public[*].id)
    assign_public_ip = false
    security_groups  = concat([aws_security_group.service_security_group.id], var.security_groups)
  }

  service_registries {
    registry_arn = aws_service_discovery_service.service.arn
  }
}

data "aws_iam_policy_document" "ec2_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs" {
  name               = "${var.stage}-${var.name}-ecs-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_role.json
}

resource "aws_iam_role_policy_attachment" "ecs_policy" {
  role       = aws_iam_role.ecs.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "ecs" {
  name  = "${var.stage}-${var.name}-ecs-profile"
  role  = aws_iam_role.ecs.name
}

resource "aws_launch_template" "configuration" {
  name_prefix   = "${var.stage}-${var.name}-"
  image_id      = var.asg_ami_id
  instance_type = var.ec2_asg_instance_type
  key_name      = aws_key_pair.ssh_key.key_name

  iam_instance_profile {
    name = aws_iam_instance_profile.ecs.name
  }

  security_group_names = [aws_security_group.ec2_security_group.name]

  user_data = base64encode(<<-EOF
              #!/bin/bash
              yum update -y
              yum install -y amazon-ecs-init
              systemctl enable --now ecs
              echo ECS_CLUSTER=${aws_ecs_cluster.cluster.name} >> /etc/ecs/ecs.config

              EOF
  )
}

resource "aws_autoscaling_group" "example" {
  desired_capacity     = var.desired_count
  max_size             = var.desired_count
  min_size             = 1
  vpc_zone_identifier  = concat(aws_subnet.private[*].id)

  launch_template {
    id      = aws_launch_template.configuration.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.stage}-${var.name}"
    propagate_at_launch = true
  }
}

resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "ssh_key" {
  key_name   = "${var.stage}-${var.name}-ssh-key"
  public_key = tls_private_key.ssh_key.public_key_openssh
}
