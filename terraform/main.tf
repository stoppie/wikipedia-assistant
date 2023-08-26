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
  description   = "Allows TCP connections from any source to any instance on the network using port 22."
  direction     = "INGRESS"
  priority      = 65534
  source_ranges = ["0.0.0.0/0"]
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
  root_password    = var.mysql_root_password

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
