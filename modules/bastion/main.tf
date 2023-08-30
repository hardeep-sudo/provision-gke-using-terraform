resource "google_project_service" "kms" {
  service            = "cloudkms.googleapis.com"
  disable_on_destroy = false
}

resource "google_compute_address" "bastion" {
  name = "${var.name}-bastion-ip"
}

resource "google_service_account" "bastion" {
  provider     = "google"
  account_id   = "${var.name}-bastion"
  display_name = "${var.name} bastion"
}

resource "google_kms_crypto_key_iam_member" "bastion" {
  crypto_key_id = "example-admin/us-central1/teleport/nodes"
  role          = "roles/cloudkms.cryptoKeyDecrypter"
  member        = "serviceAccount:${google_service_account.bastion.email}"
}

resource "google_storage_bucket_iam_member" "bastion" {
  bucket = "example-teleport-secrets"
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.bastion.email}"
}
