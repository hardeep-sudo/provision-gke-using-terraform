terraform {
  backend "gcs" {
    bucket = "example-dev-tf-state"
    prefix = "dev-bastion"
  }
}

provider "google" {
  project = "example-dev"
  region  = "us-central1"
  version = "~> 2.3.0"
}

module "bastion" {
  source = "../modules/bastion"
  name   = "dev"
}

output "ip_address" {
  value = "${module.bastion.ip_address}"
}

output "email" {
  value = "${module.bastion.email}"
}
