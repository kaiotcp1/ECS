provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
      Owner       = var.owner
      Scope       = "identity"
    }
  }
}

data "aws_caller_identity" "current" {}
