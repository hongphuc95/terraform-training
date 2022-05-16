terraform {
  backend "s3" {
    bucket = "hongphuc-terraform-backend"
    key    = "webserver/terraform.tfstate"
    region = "eu-west-3"
  }
}