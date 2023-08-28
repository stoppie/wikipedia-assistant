locals {
  project_id      = "wikipedia-assistant-397017"
  region          = "us-central1"
  service_account = "872434643787-compute@developer.gserviceaccount.com"
}

data "google_secret_manager_secret_version" "db_password" {
  secret  = "wiki-assistant-db-root-password"
  version = "latest"
}

data "google_secret_manager_secret_version" "api_user_pwd" {
  secret  = "wiki-assistant-db-api-user-password"
  version = "latest"
}

variable "source_ip" {
  description = "Source IP address to allow SSH access."
  type        = string
  sensitive   = true
}
