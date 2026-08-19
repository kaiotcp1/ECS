locals {
  ecs_tasks_assume_role_policy = templatefile("${path.module}/iam/trust/ecs-tasks.json.tftpl", {
    account_id = data.aws_caller_identity.current.account_id
    aws_region = var.aws_region
  })
}

resource "aws_iam_role" "ecs_task" {
  name               = "${var.name_prefix}-ecs-task-role"
  description        = "Provides AWS permissions to the FargateFlow application"
  assume_role_policy = local.ecs_tasks_assume_role_policy
}

resource "aws_iam_role" "ecs_task_execution" {
  name               = "${var.name_prefix}-ecs-task-execution-role"
  description        = "Allows ECS to pull images from ECR and send logs to CloudWatch"
  assume_role_policy = local.ecs_tasks_assume_role_policy
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
