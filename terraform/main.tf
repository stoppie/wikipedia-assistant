provider "google" {
  project = "wikipedia-assistant-397017"
  region  = "us-central1"
}

resource "google_compute_network" "wiki_assistant_vpc" {
  name                    = "wiki-assistant-vpc"
  auto_create_subnetworks = true
  mtu                     = 1460
  routing_mode            = "REGIONAL"
}

resource "google_compute_firewall" "wiki_assistant_allow_icmp" {
  name    = "wiki-assistant-vpc-allow-icmp"
  network = google_compute_network.wiki_assistant_vpc.name

  allow {
    protocol = "icmp"
  }

  description = "Allows ICMP connections from any source to any instance on the network."
  direction   = "INGRESS"
  priority    = 65534
  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "wiki_assistant_allow_ssh" {
  name    = "wiki-assistant-vpc-allow-ssh"
  network = google_compute_network.wiki_assistant_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  description = "Allows TCP connections from any source to any instance on the network using port 22."
  direction   = "INGRESS"
  priority    = 65534
  source_ranges = ["0.0.0.0/0"]
}