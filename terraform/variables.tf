locals {
  project_id = "wikipedia-assistant-397017"
  region     = "us-central1"
}

data "google_secret_manager_secret_version" "db_password" {
  secret  = "wiki-assistant-db-root-password"
  version = "latest"
}

variable "source_ip" {
  description = "Source IP address to allow SSH access."
  type        = string
  sensitive   = true
}
