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
    email  = "872434643787-compute@developer.gserviceaccount.com"
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
