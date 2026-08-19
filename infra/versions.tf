terraform {
  required_version = ">= 1.15.0, < 2.0.0"

  backend "s3" {
    bucket       = "kaiotcp1-terraform-state-761018861028-us-east-1"
    key          = "fargateflow/study/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.49"
    }
  }
}
