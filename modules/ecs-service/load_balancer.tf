locals {
  add_to_load_balancer = var.create_load_balancer
}

resource "aws_security_group" "load_balancer_sg" {
  vpc_id = aws_vpc.main.id
  name   = "${var.name}-load-balancer-sg"
}

resource "aws_security_group_rule" "load_balancer_ingress" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.load_balancer_sg.id
  description       = "Allow HTTP traffic from anywhere"
}

resource "aws_security_group_rule" "load_balancer_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.load_balancer_sg.id
  description       = "Allow all outbound traffic"
}


resource "aws_security_group_rule" "load_balancer_incoming_rule" {
  count = local.add_to_load_balancer ? 1 : 0

  type                     = "egress"
  from_port                = var.container_port
  to_port                  = var.container_port
  protocol                 = "tcp"
  description              = "Allow connections from ${var.name} to load balancer"
  source_security_group_id = aws_security_group.service_security_group.id
  security_group_id        = aws_security_group.load_balancer_sg.id
}

resource "aws_lb_target_group" "target_group" {
  count = local.add_to_load_balancer ? 1 : 0

  name        = trimsuffix(substr("${coalesce(var.target_group_name, var.name)}", 0, 32), "-")
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    interval            = 120
    timeout             = 30
    healthy_threshold   = 2
    unhealthy_threshold = 5
    path                = coalesce(var.health_check_path, "${var.path}/actuator/health")
  }
}

resource "aws_lb_listener_rule" "listener_rule" {
  count = local.add_to_load_balancer ? 1 : 0

  listener_arn = aws_lb_listener.http_listener.arn

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_group.0.arn
  }

  condition {
    path_pattern {
      values = ["${var.path}/*"]
    }
  }

  priority = var.priority
}

resource "aws_lb" "load_balancer" {
  name               = "${var.name}-loadbalancer"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.load_balancer_sg.id]
  subnets            = aws_subnet.public[*].id

  enable_deletion_protection = true
}

resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.load_balancer.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_group.0.arn
  }
}
