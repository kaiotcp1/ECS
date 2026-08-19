locals {
  terraform_role_name = "${var.name_prefix}-terraform-role"
  deploy_role_name    = "${var.name_prefix}-deploy-role"

  terraform_trust_policy = templatefile("${path.module}/trust/github-terraform.json.tftpl", {
    account_id        = data.aws_caller_identity.current.account_id
    github_owner      = split("/", var.github_repository)[0]
    github_repository = var.github_repository
    github_branch     = var.github_branch
  })

  deploy_trust_policy = templatefile("${path.module}/trust/github-deploy.json.tftpl", {
    account_id             = data.aws_caller_identity.current.account_id
    github_owner           = split("/", var.github_repository)[0]
    github_repository      = var.github_repository
    github_branch          = var.github_branch
    deployment_environment = var.deployment_environment
  })

  terraform_iam_policy = templatefile("${path.module}/policy/fargateflow-terraform.json.tftpl", {
    account_id  = data.aws_caller_identity.current.account_id
    name_prefix = var.name_prefix
  })

  deploy_iam_policy = templatefile("${path.module}/policy/fargateflow-deploy.json.tftpl", {
    account_id  = data.aws_caller_identity.current.account_id
    aws_region  = var.aws_region
    name_prefix = var.name_prefix
  })
}

resource "aws_iam_role" "terraform" {
  name               = local.terraform_role_name
  description        = "Provisions FargateFlow infrastructure from GitHub Actions"
  assume_role_policy = local.terraform_trust_policy

  max_session_duration = 3600
}

resource "aws_iam_role_policy_attachment" "terraform_power_user" {
  role       = aws_iam_role.terraform.name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}

resource "aws_iam_role_policy" "terraform_iam" {
  name   = "ManageFargateFlowRuntimeRoles"
  role   = aws_iam_role.terraform.id
  policy = local.terraform_iam_policy
}

resource "aws_iam_role" "deploy" {
  name               = local.deploy_role_name
  description        = "Deploys FargateFlow images and ECS task definitions from GitHub Actions"
  assume_role_policy = local.deploy_trust_policy

  max_session_duration = 3600
}

resource "aws_iam_role_policy" "deploy" {
  name   = "DeployFargateFlowApplication"
  role   = aws_iam_role.deploy.id
  policy = local.deploy_iam_policy
}
