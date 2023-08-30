output "ip_address" {
  value = "${google_compute_address.bastion.address}"
}

output "email" {
  value = "${google_service_account.bastion.email}"
}
