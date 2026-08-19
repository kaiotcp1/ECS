variable "aws_region" {
  description = "Regiao AWS na qual o ambiente temporario sera criado."
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Valor da tag Project."
  type        = string
  default     = "aws-fargate-infrastructure-lab"
}

variable "environment" {
  description = "Valor da tag Environment."
  type        = string
  default     = "study"
}

variable "owner" {
  description = "Valor da tag Owner."
  type        = string
  default     = "kaio"
}

variable "name_prefix" {
  description = "Prefixo dos nomes dos recursos do laboratorio."
  type        = string
  default     = "fargateflow"
}

variable "desired_count" {
  description = "Quantidade inicial de tarefas. O CD escala o servico depois de publicar a primeira imagem."
  type        = number
  default     = 0

  validation {
    condition     = var.desired_count >= 0 && var.desired_count <= 4
    error_message = "desired_count deve estar entre 0 e 4."
  }
}
