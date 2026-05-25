provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "three-tier-dev"
      Environment = var.environment
      ManagedBy   = "Terraform"
      Owner       = "DevOps-Team"
    }
  }
}

