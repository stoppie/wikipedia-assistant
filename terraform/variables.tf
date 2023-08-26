locals {
  project_id = "wikipedia-assistant-397017"
  region     = "us-central1"
}

variable "mysql_root_password" {
  description = "MySQL database password"
  type        = string
  sensitive   = true
}
