variable "aws_region" {
  description = "Regiao AWS que contem as roles do FargateFlow."
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Valor da tag Project."
  type        = string
  default     = "aws-fargate-infrastructure-lab"
}

variable "environment" {
  description = "Valor da tag Environment para recursos de identidade."
  type        = string
  default     = "study"
}

variable "owner" {
  description = "Valor da tag Owner."
  type        = string
  default     = "kaio"
}

variable "name_prefix" {
  description = "Prefixo dos nomes de roles e recursos do laboratorio."
  type        = string
  default     = "fargateflow"
}

variable "github_repository" {
  description = "Repositorio GitHub autorizado a assumir as roles da aplicacao."
  type        = string
  default     = "kaiotcp1/ECS"
}

variable "github_branch" {
  description = "Branch autorizada para Terraform e deploy."
  type        = string
  default     = "main"
}

variable "deployment_environment" {
  description = "GitHub Environment exigido para assumir a role de deploy."
  type        = string
  default     = "production"
}
