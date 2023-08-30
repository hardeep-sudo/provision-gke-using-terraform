terraform {
  backend "gcs" {
    bucket = "example-dev-tf-state"
    prefix = "dev-cluster"
  }
}

data "terraform_remote_state" "network" {
  backend = "gcs"

  config = {
    bucket = "example-dev-tf-state"
    prefix = "dev-network"
  }
}

module "cluster" {
  source = "../modules/cluster"

  name     = "dev"
  project  = "example-dev"
  region   = "us-central1"
  location = "us-central1-c"
  network  = data.terraform_remote_state.network.outputs.network_name
  node_count = 1

  cluster_subnetwork = data.terraform_remote_state.network.outputs.cluster_subnetwork_name

  # Node pool config
  default_node_pool_node_count   = 1
  default_node_pool_machine_type = "n1-standard-8"
  
  enable_security_policy             = false
  enable_cf_security_policy          = true
  enable_stackdriver_service_account = false

  ip_whitelist = ["ip-address/32"]

  master_authorized_cidr_blocks = [
    {
      cidr_block   = "ip-address/32"
      display_name = "vpn-access"
    },
    {
      cidr_block   = "ip-address/32"
      display_name = "CI-nat-0"
    },
    {
      cidr_block   = "ip-address/32"
      display_name = "CI-nat-1"
    },
  ]

  # security settings
  enable_private_endpoint     = false
  enable_private_nodes        = true
  enable_binary_authorization = false
  pod_security_policy_enabled = false
}

