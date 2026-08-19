resource "aws_ecr_repository" "app" {
  name                 = var.name_prefix
  image_tag_mutability = "IMMUTABLE"
  force_delete         = true

  encryption_configuration {
    encryption_type = "AES256"
  }

  image_scanning_configuration {
    scan_on_push = false
  }
}

resource "aws_ecr_registry_scanning_configuration" "app" {
  scan_type = "BASIC"

  rule {
    scan_frequency = "SCAN_ON_PUSH"

    repository_filter {
      filter      = aws_ecr_repository.app.name
      filter_type = "WILDCARD"
    }
  }
}

resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep only the 10 most recent images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = {
        type = "expire"
      }
    }]
  })
}
