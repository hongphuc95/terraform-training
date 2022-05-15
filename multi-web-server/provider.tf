terraform {
  required_version = ">1.0.0"

  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

# Set region explicitly to Paris (eu-west-3)
provider "aws" {
  region = "eu-west-3"
}