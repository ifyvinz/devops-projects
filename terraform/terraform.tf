terraform {
  required_version = ">= 1.8.3"

  backend "s3" {
    bucket       = "my-terraform-state-devops-project"
    key          = "prod/aws_infra"
    region       = "eu-north-1"
    
  }

  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    http = {
      source  = "hashicorp/http"
      version = "2.1.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.1.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.1.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "3.1.0"
    }
  }
}
