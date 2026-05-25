terraform {
  backend "s3" {
    bucket         = "terraform-state-dev"
    key            = "three-tier/dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}

