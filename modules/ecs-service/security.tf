resource "aws_security_group" "service_security_group" {
  name   = "${var.name}-service-sg"
  vpc_id = aws_vpc.main.id

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "internet_access" {
  for_each = toset([for port in var.outgoing_tcp_ports : tostring(port)])

  security_group_id = aws_security_group.service_security_group.id
  type              = "egress"

  from_port   = each.value
  to_port     = each.value
  protocol    = "tcp"
  description = "Allows connections to the internet on TCP port ${each.value}"
  cidr_blocks = ["0.0.0.0/0"]
  ipv6_cidr_blocks = ["::/0"]
}

resource "aws_security_group_rule" "allow_load_balancer_access" {
  type              = "ingress"
  security_group_id = aws_security_group.service_security_group.id

  from_port                = var.container_port
  to_port                  = var.container_port
  protocol                 = "tcp"
  description              = "Allow connections from load balancer"
  source_security_group_id = aws_security_group.load_balancer_sg.id
}

resource "aws_security_group" "ec2_security_group" {
  name   = "${var.name}-ec2-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.service_security_group.id]
    description     = "Allow proxy instance to connect to ECS agent instances via SSH"
  }

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allows connections to the ECS agent instances from the interface security group"
  }
}