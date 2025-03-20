data "aws_iam_policy_document" "assume_ecs_tasks" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

locals {
  repository_arn = aws_ecr_repository.repository.0.arn
}

data "aws_iam_policy_document" "execution_role_policy" {
  dynamic "statement" {
    for_each = local.repository_arn == null ? [] : ["repository"]

    content {
      actions = [
        "ecr:BatchCheckLayerAvailability",
        "ecr:BatchGetImage",
        "ecr:GetDownloadUrlForLayer"
      ]
      effect    = "Allow"
      resources = [local.repository_arn]
    }
  }

  dynamic "statement" {
    for_each = local.repository_arn == null ? [] : ["repository"]

    content {
      actions   = ["ecr:GetAuthorizationToken"]
      effect    = "Allow"
      resources = ["*"]
    }
  }

  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    effect    = "Allow"
    resources = [aws_cloudwatch_log_group.container_log.arn]
  }
}

data "aws_iam_policy" "ecs_task_execution" {
  name = "AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "execution_role" {
  name                = "${var.name}-execution-role"
  assume_role_policy  = data.aws_iam_policy_document.assume_ecs_tasks.json
}

resource "aws_iam_role_policy_attachment" "execution_role_policy" {
  role       = aws_iam_role.execution_role.name
  policy_arn = data.aws_iam_policy.ecs_task_execution.arn
  
}

resource "aws_iam_role_policy" "execution_role_policy" {
  name   = "${var.name}-execution-role-policy"
  role   = aws_iam_role.execution_role.id
  policy = data.aws_iam_policy_document.execution_role_policy.json
}

data "aws_iam_policy_document" "task_role_policy" {
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents",
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel"
    ]
    effect    = "Allow"
    resources = ["*"]
  }
}
resource "aws_iam_role" "task_role" {
  name               = "${var.name}-task-role"
  assume_role_policy = data.aws_iam_policy_document.assume_ecs_tasks.json
}

resource "aws_iam_role_policy" "task_role_policy" {
  name   = "${var.name}-task-role-policy"
  role   = aws_iam_role.task_role.id
  policy = data.aws_iam_policy_document.task_role_policy.json
}
