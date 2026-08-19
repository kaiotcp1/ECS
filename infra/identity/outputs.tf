output "terraform_role_arn" {
  description = "ARN da role usada pelo workflow Terraform do FargateFlow."
  value       = aws_iam_role.terraform.arn
}

output "deploy_role_arn" {
  description = "ARN da role usada pelo workflow de deploy do FargateFlow."
  value       = aws_iam_role.deploy.arn
}
