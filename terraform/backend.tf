terraform {
  backend "s3" {
    bucket = "homelab-terraform-state-fb33c698"
    key    = "homelab/terraform.tfstate"
    region = "us-east-1"
  }
}
