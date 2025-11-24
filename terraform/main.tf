terraform {
  required_version = ">= 1.13.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
  }
}

provider "google" {
  credentials = file("~/.gcp/terraform-key.json")

  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# --- Network ---

resource "google_compute_network" "spark_vpc" {
  name                    = "spark-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "spark_subnet" {
  name          = "spark-subnet"
  ip_cidr_range = "10.10.0.0/16"
  region        = var.region
  network       = google_compute_network.spark_vpc.id
}

resource "google_compute_firewall" "spark_allow_ssh_sparkui" {
  name    = "spark-allow-ssh-sparkui"
  network = google_compute_network.spark_vpc.name
  project = var.project_id

  allow {
    protocol = "tcp"
    ports    = [
      "22",
      "7077",
      "8080",
      "4040-4050",
      "9870",       
      "9864"        
    ]
  }

  source_ranges = ["0.0.0.0/0"]
}

# --- Common image info ---

locals {
  image_family  = "ubuntu-2204-lts"
  image_project = "ubuntu-os-cloud"
}

# --- Spark master node ---

resource "google_compute_instance" "spark_master" {
  name         = "spark-master"
  machine_type = var.machine_type
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "projects/${local.image_project}/global/images/family/${local.image_family}"
      size  = 30
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.spark_subnet.name
    access_config {}
  }

  tags = ["spark-master", "ssh"]

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/gcp_spark_key.pub")}"
  }
}

# --- Spark worker nodes ---

resource "google_compute_instance" "spark_worker" {
  count        = var.worker_count
  name         = "spark-worker-${count.index}"
  machine_type = var.machine_type
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "projects/${local.image_project}/global/images/family/${local.image_family}"
      size  = 30
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.spark_subnet.name
    access_config {}
  }

  tags = ["spark-worker", "ssh"]

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/gcp_spark_key.pub")}"
  }
}


resource "google_compute_instance" "spark_edge" {
  name         = "spark-edge"
  machine_type = var.machine_type
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "projects/${local.image_project}/global/images/family/${local.image_family}"
      size  = 20
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.spark_subnet.name
    access_config {}
  }

  tags = ["spark-edge", "ssh"]

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/gcp_spark_key.pub")}"
  }
}

# --- Outputs ---

output "spark_master_ip" {
  description = "External IP of Spark master"
  value       = google_compute_instance.spark_master.network_interface[0].access_config[0].nat_ip
}

output "spark_worker_ips" {
  description = "External IPs of Spark workers"
  value = [
    for w in google_compute_instance.spark_worker :
    w.network_interface[0].access_config[0].nat_ip
  ]
}

output "spark_edge_ip" {
  description = "External IP of edge node"
  value       = google_compute_instance.spark_edge.network_interface[0].access_config[0].nat_ip
}
