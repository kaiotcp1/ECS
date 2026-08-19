terraform {
  required_version = ">= 1.15.0, < 2.0.0"

  backend "s3" {
    bucket       = "terraform-states-761018861028-us-east-1"
    key          = "fargateflow/identity/terraform.tfstate"
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
