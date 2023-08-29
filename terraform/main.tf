# Provider Configuration
terraform {
  required_providers {
    google = "~> 4.0"
  }
}

provider "google" {
  project = local.project_id
  region  = local.region
}

# Networking

# VPC Network Configuration
resource "google_compute_network" "wiki_assistant_vpc" {
  name                    = "wiki-assistant-vpc"
  auto_create_subnetworks = true
  mtu                     = 1460
  routing_mode            = "REGIONAL"
}

# Private IP Configuration for VPC Peering
resource "google_compute_global_address" "private_ip_address" {
  name          = "wiki-assistant-private-ip-range"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.wiki_assistant_vpc.self_link
}

# Private VPC Connection Configuration
resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.wiki_assistant_vpc.self_link
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]
}

# VPC Connector Configuration
resource "google_vpc_access_connector" "wiki_assistant_connector" {
  name          = "wiki-assistant-connector"
  region        = local.region
  network       = google_compute_network.wiki_assistant_vpc.name
  ip_cidr_range = "10.8.0.0/28"
}


# Firewall Rules

# ICMP Firewall Rule
resource "google_compute_firewall" "wiki_assistant_allow_icmp" {
  name          = "wiki-assistant-vpc-allow-icmp"
  network       = google_compute_network.wiki_assistant_vpc.name
  description   = "Allows ICMP connections from any source to any instance on the network."
  direction     = "INGRESS"
  priority      = 65534
  source_ranges = ["0.0.0.0/0"]
  allow {
    protocol = "icmp"
  }
}

# SSH Firewall Rule
resource "google_compute_firewall" "wiki_assistant_allow_ssh" {
  name          = "wiki-assistant-vpc-allow-ssh"
  network       = google_compute_network.wiki_assistant_vpc.name
  description   = "Allows TCP connections from a specific source to any instance on the network using port 22."
  direction     = "INGRESS"
  priority      = 65534
  source_ranges = [var.source_ip]
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

# Database Configuration

# SQL Database Instance Configuration
resource "google_sql_database_instance" "wiki_assistant_db" {
  name             = "wiki-assistant-db"
  database_version = "MYSQL_8_0_31"
  region           = local.region
  root_password    = data.google_secret_manager_secret_version.db_password.secret_data

  settings {
    tier                        = "db-custom-1-3840"
    deletion_protection_enabled = true
    disk_autoresize             = false
    disk_size                   = 20
    disk_type                   = "PD_SSD"
    activation_policy           = "ALWAYS"
    availability_type           = "ZONAL"
    pricing_plan                = "PER_USE"

    backup_configuration {
      location           = "us"
      binary_log_enabled = true
      enabled            = true
      start_time         = "04:00"

      backup_retention_settings {
        retained_backups = 7
      }

      transaction_log_retention_days = 7
    }

    location_preference {
      zone = "us-central1-b"
    }

    ip_configuration {
      private_network                               = "projects/wikipedia-assistant-397017/global/networks/wiki-assistant-vpc"
      ipv4_enabled                                  = false
      allocated_ip_range                            = "wiki-assistant-private-ip-range"
      enable_private_path_for_google_cloud_services = true
    }

    insights_config {
      query_insights_enabled = false
    }

    maintenance_window {
      day          = 5
      hour         = 22
      update_track = "stable"
    }

    edition = "ENTERPRISE"
  }

  timeouts {}
}

# Compute Instances Configuration

# SQL Connector Instance
resource "google_compute_instance" "wiki_assistant_sql_connector" {
  boot_disk {
    auto_delete = true
    device_name = "wiki-assistant-sql-connector"

    initialize_params {
      image = "projects/debian-cloud/global/images/debian-12-bookworm-v20230814"
      size  = 10
      type  = "pd-balanced"
    }

    mode = "READ_WRITE"
  }

  can_ip_forward      = false
  deletion_protection = false
  enable_display      = false

  labels = {
    goog-ec-src = "vm_add-tf"
  }

  machine_type = "e2-micro"

  metadata = {
    startup-script = "sudo apt update\nsudo apt install -y default-mysql-client pip python3-venv"
  }

  name = "wiki-assistant-sql-connector"

  network_interface {
    access_config {
      network_tier = "PREMIUM"
    }

    subnetwork = "projects/wikipedia-assistant-397017/regions/us-central1/subnetworks/wiki-assistant-vpc"
  }

  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
    preemptible         = false
    provisioning_model  = "STANDARD"
  }

  service_account {
    email  = local.service_account
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  shielded_instance_config {
    enable_integrity_monitoring = true
    enable_secure_boot          = false
    enable_vtpm                 = true
  }

  tags                      = ["https-server"]
  zone                      = "us-central1-b"
  allow_stopping_for_update = true
}

# Cloud Run Configuration

# Docker Image Repository
resource "google_artifact_registry_repository" "wiki_assistant_repo" {
  location      = "us-central1"
  repository_id = "wiki-assistant-repo"
  description   = "Docker repository for the Wiki Assistant app."
  format        = "DOCKER"
}

# Cloud Run Service Configuration
resource "google_cloud_run_v2_service" "wiki_assistant_service" {
  client   = "cloud-console"
  name     = "wiki-assistant"
  location = "us-central1"

  template {
    vpc_access {
      connector = google_vpc_access_connector.wiki_assistant_connector.id
      egress    = "PRIVATE_RANGES_ONLY"
    }

    containers {
      image = "us-central1-docker.pkg.dev/wikipedia-assistant-397017/wiki-assistant-repo/wiki-assistant@sha256:cf697fb44d7c8ce1c6b471df8cea27bd6799ba5317cd91f6c7de20cb12ad596c"

      resources {
        cpu_idle = true
        limits = {
          memory = "128Mi"
          cpu    = "1000m"
        }
      }

      env {
        name  = "PROJECT_ID"
        value = local.project_id
      }

      env {
        name  = "SECRET_VERSION"
        value = "wiki-assistant-db-api-user-password"
      }

      env {
        name  = "DATABASE_HOSTNAME"
        value = "wiki-assistant-db"
      }

      env {
        name = "MYSQL_PWD"
        value_source {
          secret_key_ref {
            secret  = data.google_secret_manager_secret_version.api_user_pwd.secret
            version = "latest"
          }
        }
      }
    }

    max_instance_request_concurrency = 10
    service_account                  = local.service_account
  }

  traffic {
    percent = 100
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
  }

  timeouts {}
}

resource "google_cloud_run_v2_service_iam_binding" "wiki_assistant_service_public" {
  name     = google_cloud_run_v2_service.wiki_assistant_service.name
  location = google_cloud_run_v2_service.wiki_assistant_service.location
  role     = "roles/run.invoker"
  members  = ["allUsers"]
}

# Cloud Run Job Configuration
resource "google_cloud_run_v2_job" "wiki_assistant_job" {
  client   = "cloud-console"
  name     = "wiki-assistant-update"
  location = "us-central1"

  labels = {}

  template {
    labels = {}

    template {
      service_account = local.service_account
      max_retries     = 2
      timeout         = "18000s"

      vpc_access {
        connector = google_vpc_access_connector.wiki_assistant_connector.id
        egress    = "PRIVATE_RANGES_ONLY"
      }

      containers {
        image   = "us-central1-docker.pkg.dev/wikipedia-assistant-397017/wiki-assistant-repo/wiki-assistant-update@sha256:26fd0eddd845ccd54494ebb3f89592f5babf188fa0ec361fcf444a0ba6e8f549"
        args    = []
        command = []

        resources {
          limits = {
            memory = "2Gi"
            cpu    = "1000m"
          }
        }
      }
    }
  }

  timeouts {}
}

# Cloud Scheduler Configuration
resource "google_cloud_scheduler_job" "wiki_assistant_update_scheduler" {
  name        = "wiki-assistant-update-scheduler"
  description = "Scheduler for the Cloud Run job responsible for monthly updates."
  schedule    = "0 1 2 * *"
  time_zone   = "UTC"

  retry_config {
    retry_count = 0
  }

  http_target {
    http_method = "POST"
    uri         = "https://us-central1-run.googleapis.com/apis/run.googleapis.com/v1/namespaces/wikipedia-assistant-397017/jobs/wiki-assistant-update:run"

    oauth_token {
      service_account_email = local.service_account
      scope                 = "https://www.googleapis.com/auth/cloud-platform"
    }
  }
}
