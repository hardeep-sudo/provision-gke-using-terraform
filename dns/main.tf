terraform {
  backend "gcs" {
    bucket = "example-dev-tf-state"
    prefix = "dev-dns"
  }
}

resource "google_project_service" "dns" {
  project            = "example-dev"
  service            = "dns.googleapis.com"
  disable_on_destroy = false
}

##
## ENVIRONMENT: DEV
##

resource "google_dns_managed_zone" "example-dev-dev1" {
  name        = "example-dev-dev1"
  dns_name    = "dev1.example.io."
  depends_on  = [ google_project_service.dns ]
  project     = "example-dev"
  description = "Managed by Terraform"
}

resource "google_dns_record_set" "fqdn-dev1" {
  project      = "example-dev"
  count        = length(var.example_subdomains)
  name         = "${var.example_subdomains[count.index]}.${google_dns_managed_zone.example-dev-dev1.dns_name}"
  type         = "A"
  ttl          = 300
  managed_zone = google_dns_managed_zone.example-dev-dev1.name
  rrdatas      = ["1.1.1.1"]
}