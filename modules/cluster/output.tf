output "zone" {
  value = google_container_cluster.default.location
}

output "node_svc_account" {
  value = google_service_account.nodes.email
}

