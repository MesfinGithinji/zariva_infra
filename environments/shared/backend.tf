terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    bucket         = "zariva-terraform-state"
    key            = "shared/terraform.tfstate"
    region         = "us-east-1"
    use_lockfile   = true # Native S3 state locking
  }
}

provider "aws" {
  region = "us-east-1"
  default_tags {
    tags = {
      Project   = "zariva"
      ManagedBy = "Terraform"
      Stack     = "shared"
    }
  }
}