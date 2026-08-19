resource "aws_security_group" "alb" {
  name        = local.names.alb_security_group
  description = "Allows public HTTP traffic to the FargateFlow ALB"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = local.names.alb_security_group
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "Public HTTP access"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_security_group" "ecs_tasks" {
  name        = local.names.tasks_security_group
  description = "Allows application traffic only from the FargateFlow ALB"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = local.names.tasks_security_group
  }
}

resource "aws_vpc_security_group_egress_rule" "alb_to_tasks" {
  security_group_id            = aws_security_group.alb.id
  description                  = "Application traffic to ECS tasks"
  from_port                    = 3000
  to_port                      = 3000
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.ecs_tasks.id
}

resource "aws_vpc_security_group_ingress_rule" "tasks_from_alb" {
  security_group_id            = aws_security_group.ecs_tasks.id
  description                  = "Application traffic from the ALB"
  from_port                    = 3000
  to_port                      = 3000
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.alb.id
}

resource "aws_vpc_security_group_egress_rule" "tasks_outbound" {
  security_group_id = aws_security_group.ecs_tasks.id
  description       = "Outbound access for ECR, CloudWatch and dependencies"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}
