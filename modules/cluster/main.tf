provider "google" {
  project = var.project
  region  = var.region
}

provider "google-beta" {
  project = var.project
  region  = var.region
}

provider "null" {
  version = "~> 2.1.2"
}

data "google_project" "project" {
}

# writes info to file for convenience
resource "null_resource" "info" {
  count = var.write_output ? 1 : 0

  provisioner "local-exec" {
    command = <<EOF
      ${path.module}/../output.sh ${path.cwd} project ${data.google_project.project.name}
      ${path.module}/../output.sh ${path.cwd} cluster_name ${var.name}
      ${path.module}/../output.sh ${path.cwd} cluster_location ${var.location}
      ${path.module}/../output.sh ${path.cwd} container_registry ${var.container_registry_bucket}
      ${path.module}/../output.sh ${path.cwd} stackdriver_svc_account ${join("", google_service_account.stackdriver.*.email)}
    
EOF

  }

  triggers = {
    project            = data.google_project.project.name
    cluster_name       = var.name
    location           = var.location
    container_registry = var.container_registry_bucket
  }
}

locals {
  ip_whitelist = concat([
    "ip-address/32",
    "ip-address/32"
     ], var.ip_whitelist)
  // this is a hack to allow up to 10 whitelist ip addresses. It results in duplicate security
  // rules, but that is the best option at this point. Terraform 0.12.x should allow us to get
  // rid of this as it supports dynamic blocks
  ip_whielist_max = length(var.ip_whitelist) + 1
  ip_whielist_min = length(local.ip_whitelist) + 1 > 5 ? 5 : 0
  cloudflare1 = [
    "ip-address/22",
  ]
}

###################################################################################
# project-level config
###################################################################################
resource "google_project_service" "gke" {
  provider           = google
  service            = "container.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "binary_authorization" {
  provider           = google
  service            = "binaryauthorization.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "container_registry" {
  provider           = google
  service            = "containerregistry.googleapis.com"
  disable_on_destroy = false
}

###################################################################################
# IAM
###################################################################################
resource "google_service_account" "nodes" {
  provider     = google
  account_id   = "${var.name}-gke-node"
  display_name = "${var.name} GKE node service account"
}

resource "google_project_iam_member" "monitoring_viewer" {
  provider = google
  role     = "roles/monitoring.viewer"
  member   = "serviceAccount:${google_service_account.nodes.email}"
}

resource "google_project_iam_member" "monitoring_writer" {
  provider = google
  role     = "roles/monitoring.metricWriter"
  member   = "serviceAccount:${google_service_account.nodes.email}"
}

resource "google_project_iam_member" "logging_writer" {
  provider = google
  role     = "roles/logging.logWriter"
  member   = "serviceAccount:${google_service_account.nodes.email}"
}

resource "google_storage_bucket_iam_member" "gcr" {
  provider = google
  bucket   = var.container_registry_bucket
  role     = "roles/storage.objectViewer"
  member   = "serviceAccount:${google_service_account.nodes.email}"
}

resource "google_service_account" "stackdriver" {
  provider     = google
  count        = var.enable_stackdriver_service_account ? 1 : 0
  account_id   = "${var.name}-stackdriver"
  display_name = "${var.name} stackdriver write ability (prometheus-to-sd)"
}

resource "google_project_iam_member" "stackdriver_metrics_writer" {
  provider = google
  count    = var.enable_stackdriver_service_account ? 1 : 0
  role     = "roles/monitoring.metricWriter"
  member   = "serviceAccount:${google_service_account.stackdriver[0].email}"
}

###################################################################################
# GKE Cluster
###################################################################################

# The cluster defaults to using the security best practices outlined in the following resource.
# https://cloud.google.com/kubernetes-engine/docs/how-to/hardening-your-cluster
# Best practices config is also noted within the cluster block below with `security best practice`
resource "google_container_cluster" "default" {
  provider           = google-beta
  depends_on         = [google_project_service.gke]
  name               = var.name
  location           = var.location
  node_locations     = var.node_locations
  min_master_version = var.min_master_version

  # there is a terraform bug that makes it re-apply network settings when the node_pool is set
  # this setup will create the default-pool and then delete it. There are advantages to managing
  # node-pools outside of the cluster configuration
  # https://github.com/terraform-providers/terraform-provider-google/issues/1566
  initial_node_count = 1

  remove_default_node_pool = true

  network    = var.network
  subnetwork = var.cluster_subnetwork

  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_ip_range
    services_secondary_range_name = var.services_ip_range
  }

  maintenance_policy {
    daily_maintenance_window {
      start_time = var.daily_maintenance_start_time
    }
  }

  enable_binary_authorization = var.enable_binary_authorization

  addons_config {
    network_policy_config {
      disabled = false
    }
  }

  # security best practice - disabled by default
  enable_legacy_abac = false

  # security best practice - allows use of NetworkPolicy resource
  network_policy {
    provider = "CALICO"
    enabled  = true
  }

  master_auth {
    # security best practice - disables basic authentication
    username = ""
    password = ""

    # security best practice - disables x509 certificate authentication
    client_certificate_config {
      issue_client_certificate = false
    }
  }

  # security best practice
  pod_security_policy_config {
    enabled = var.pod_security_policy_enabled
  }

  private_cluster_config {
    enable_private_endpoint = var.enable_private_endpoint
    enable_private_nodes    = var.enable_private_nodes
    master_ipv4_cidr_block  = var.master_ipv4_cidr_block
  }

  master_authorized_networks_config {
    dynamic "cidr_blocks" {
      for_each = var.master_authorized_cidr_blocks
      content {
        cidr_block   = cidr_blocks.value.cidr_block
        display_name = lookup(cidr_blocks.value, "display_name", null)
      }
    }
  }

  logging_service    = "logging.googleapis.com/kubernetes"
  monitoring_service = "monitoring.googleapis.com/kubernetes"

  lifecycle {
    ignore_changes = [node_pool]
  }
}

###################################################################################
# GKE Node Pools
###################################################################################
resource "google_container_node_pool" "default" {
  provider   = google-beta
  name       = "default"
  cluster    = google_container_cluster.default.name
  location   = google_container_cluster.default.location
  node_count = 0

  version = var.node_auto_upgrade ? "" : var.node_version

  max_pods_per_node = var.default_node_pool_max_pods

  autoscaling {
    max_node_count = 1
    min_node_count = 0
  }

  management {
    auto_upgrade = false
    auto_repair  = true
  }

  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
  }

  node_config {
    machine_type    = var.default_node_pool_machine_type
    service_account = google_service_account.nodes.email

    # control access via service account rather than scopes
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]

    labels = {
      nodeType = "default"
    }

    # security best practice - prevents workload access to instance metadata
    workload_metadata_config {
      node_metadata = "SECURE"
    }

    metadata = {
      disable-legacy-endpoints = "true"
    }
  }
}

resource "google_container_node_pool" "matching_engine" {
  provider   = google-beta
  count      = var.enable_matching_engine_node_pool ? 1 : 0
  name       = "matching-engine"
  cluster    = google_container_cluster.default.name
  location   = google_container_cluster.default.location
  node_count = var.matching_engine_node_pool_node_count

  version = var.node_auto_upgrade ? "" : var.node_version

  max_pods_per_node = var.matching_engine_node_pool_max_pods

  management {
    auto_upgrade = false
    auto_repair  = true
  }

  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
  }

  node_config {
    machine_type    = var.matching_engine_node_pool_machine_type
    service_account = google_service_account.nodes.email

    # control access via service account rather than scopes
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]

    labels = {
      "nodeType" = "matching-engine"
    }

    # security best practice - prevents workload access to instance metadata
    workload_metadata_config {
      node_metadata = "SECURE"
    }

    metadata = {
      disable-legacy-endpoints = "true"
    }

    taint {
      key    = "role"
      value  = "matching-engine"
      effect = "NO_SCHEDULE"
    }
    
  }
}

resource "google_container_node_pool" "blockbook" {
  provider   = google-beta
  count      = var.enable_blockbook_node_pool ? 1 : 0
  name       = "blockbook"
  cluster    = google_container_cluster.default.name
  location   = google_container_cluster.default.location
  node_count = var.blockbook_node_pool_node_count

  version = var.node_auto_upgrade ? "" : var.node_version

  max_pods_per_node = var.blockbook_node_pool_max_pods

  autoscaling {
    max_node_count = 1
    min_node_count = 0
  }

  management {
    auto_upgrade = false
    auto_repair  = true
  }

  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
  }

  node_config {
    machine_type    = var.blockbook_node_pool_machine_type
    service_account = google_service_account.nodes.email

    # control access via service account rather than scopes
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]

    labels = {
      nodeType = "blockbook"
    }

    # security best practice - prevents workload access to instance metadata
    workload_metadata_config {
      node_metadata = "SECURE"
    }

    metadata = {
      disable-legacy-endpoints = "true"
    }

    taint {
      key    = "role"
      value  = "blockbook"
      effect = "NO_SCHEDULE"
    }
  }
}

resource "google_container_node_pool" "redis" {
  provider   = google-beta
  count      = var.enable_redis_node_pool ? 1 : 0
  name       = "redis"
  cluster    = google_container_cluster.default.name
  location   = google_container_cluster.default.location
  initial_node_count = 1
  node_locations = [ "us-central1-f" ]

  version = var.node_auto_upgrade ? "" : var.node_version

  max_pods_per_node = var.redis_node_pool_max_pods

  management {
    auto_upgrade = false
    auto_repair  = true
  }

  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
  }

  node_config {
    machine_type    = var.redis_node_pool_machine_type
    service_account = google_service_account.nodes.email

    # control access via service account rather than scopes
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]

    labels = {
      nodeType = "redis"
    }

    # security best practice - prevents workload access to instance metadata
    workload_metadata_config {
      node_metadata = "SECURE"
    }

    metadata = {
      disable-legacy-endpoints = "true"
    }

    taint {
      key    = "role"
      value  = "redis"
      effect = "NO_SCHEDULE"
    }
  }
}

resource "google_container_node_pool" "kafka" {
  provider   = google-beta
  count      = var.enable_kafka_node_pool ? 1 : 0
  name       = "kafka"
  cluster    = google_container_cluster.default.name
  location   = google_container_cluster.default.location
  node_count = var.kafka_node_pool_node_count

  version = var.node_auto_upgrade ? "" : var.node_version

  max_pods_per_node = var.kafka_node_pool_max_pods

  management {
    auto_upgrade = var.node_auto_upgrade
    auto_repair  = true
  }

  node_config {
    machine_type    = var.kafka_node_pool_machine_type
    service_account = google_service_account.nodes.email

    # control access via service account rather than scopes
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]

    labels = {
      nodeType = "kafka"
    }

    # security best practice - prevents workload access to instance metadata
    workload_metadata_config {
      node_metadata = "SECURE"
    }

    metadata = {
      "disable-legacy-endpoints" = "true"
    }

    taint {
      key    = "role"
      value  = "kafka"
      effect = "NO_SCHEDULE"
    }
  }
}

resource "google_container_node_pool" "cas" {
  provider   = google-beta
  count      = var.enable_cas_node_pool ? 1 : 0
  name       = "cas"
  cluster    = google_container_cluster.default.name
  location   = google_container_cluster.default.location
  node_count = var.cas_node_pool_count

  version = "1.16.15-gke.4901"

  max_pods_per_node = 16

  management {
    auto_upgrade = var.node_auto_upgrade
    auto_repair  = true
  }

  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
  }

  node_config {
    machine_type    = var.cas_node_pool_machine_type
    service_account = google_service_account.nodes.email

    # control access via service account rather than scopes
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]

    labels = {
      "nodeType" = "cas"
    }

    # security best practice - prevents workload access to instance metadata
    workload_metadata_config {
      node_metadata = "SECURE"
    }

    metadata = {
      "disable-legacy-endpoints" = "true"
    }

    taint {
      key    = "role"
      value  = "cas"
      effect = "NO_SCHEDULE"
    }
  }
}

###################################################################################
# Security Policy
###################################################################################
resource "google_compute_security_policy" "policy" {
  count = var.enable_security_policy ? 1 : 0
  name  = "${var.name}-lb-policy"

  rule {
    action   = "allow"
    priority = "1000"

    match {
      versioned_expr = "SRC_IPS_V1"

      config {
        src_ip_ranges = slice(local.ip_whitelist, 0, min(local.ip_whielist_max, 5))
      }
    }

    description = "Allow access internal access"
  }

  rule {
    action   = "allow"
    priority = "1011"

    match {
      versioned_expr = "SRC_IPS_V1"

      config {
        src_ip_ranges = slice(local.ip_whitelist_two, 0, min(local.ip_whielist_two_max, 5))
      }
    }

    description = "Allow access internal access #02"
  }

  rule {
    action   = "allow"
    priority = "1001"

    match {
      versioned_expr = "SRC_IPS_V1"

      config {
        
        src_ip_ranges = slice(
          local.ip_whitelist,
          local.ip_whielist_min,
          local.ip_whielist_max,
        )
      }
    }

    description = "Allow access internal access"
  }

  rule {
    action   = "deny(403)"
    priority = "2147483647"

    match {
      versioned_expr = "SRC_IPS_V1"

      config {
        src_ip_ranges = ["*"]
      }
    }

    description = "default rule"
  }
}

# cloud armor rules can only have 5 ips, so cloudflare is broken into groups
resource "google_compute_security_policy" "cloudflare" {
  count = var.enable_cf_security_policy ? 1 : 0
  name  = "${var.name}-cf-lb-policy"

  rule {
    action   = "allow"
    preview  = false
    priority = "1000"

    match {
      versioned_expr = "SRC_IPS_V1"

      config {
        src_ip_ranges = local.ip_whitelist
      }
    }

    description = "Allow access to VPN IP"
  }

  rule {
    action   = "allow"
    preview  = false
    priority = "1001"

    match {
      versioned_expr = "SRC_IPS_V1"

      config {
        src_ip_ranges = local.cloudflare1
      }
    }

    description = "Allow Cloudflare block 1"
  }

  rule {
    action   = "allow"
    preview  = false
    priority = "1002"

    match {
      versioned_expr = "SRC_IPS_V1"

      config {
        src_ip_ranges = local.cloudflare2
      }
    }

    description = "Allow Cloudflare block 2"
  }

  rule {
    action   = "allow"
    preview  = false
    priority = "1003"

    match {
      versioned_expr = "SRC_IPS_V1"

      config {
        src_ip_ranges = local.cloudflare3
      }
    }

    description = "Allow Cloudflare block 3"
  }

  rule {
    action   = "deny(403)"
    preview  = false
    priority = "2147483647"

    match {
      versioned_expr = "SRC_IPS_V1"

      config {
        src_ip_ranges = ["*"]
      }
    }

    description = "default rule"
  }
}

