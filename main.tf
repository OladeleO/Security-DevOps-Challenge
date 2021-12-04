provider "google" {
   version = "3.53"
   
   
   project = var.project
   region  = var.region
   zone    = var.zone
}

#resource "google_container_cluster" "my_vpc_native_cluster" {
#   name                 = var.gke_cluster_name
#   location             = var.zone
#   initial_node_count   = 1
   
#   network              = "default"
#   subnetwork           = "default"
  
#}


##### 1st VPC Creation

resource "google_compute_network" "vpc_network_1" {
  project                 = var.project
  name                    = "vpc-server-github-actions"
  auto_create_subnetworks = false
  mtu                     = 1460
}


##### 2nd VPC Creation
resource "google_compute_network" "vpc_network_2" {
  project                 = var.project
  name                    = "vpc-client-github-actions"
  auto_create_subnetworks = false 
  mtu                     = 1460
}

##### Subnetwork 1st VPC
resource "google_compute_subnetwork" "public-subnetwork_1" {
  name          = "subnet-server-github-actions"
  ip_cidr_range = "10.10.10.0/24"
  region        = "europe-west1"
  network       = google_compute_network.vpc_network_1.name
}

##### Subnetwork 2nd VPC
resource "google_compute_subnetwork" "public-subnetwork_2" {
  name          = "subnet-client-github-actions"
  ip_cidr_range = "192.168.1.0/24"
  region        = "europe-west2"
  network       = google_compute_network.vpc_network_2.name
}

##### Firewall rule 1st VPC
resource "google_compute_firewall" "default_1" {
  name    = "allow-icmp-ssh"
  network = google_compute_network.vpc_network_1.name

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

##### Firewall rule 2nd VPC
resource "google_compute_firewall" "default_2" {
  name    = "allow-icmp-ssh-http"
  network = google_compute_network.vpc_network_2.name

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["22","80"]
  }
}

##### VM Client Creation
resource "google_compute_instance" "vm_1" {
  provider     = google-beta
  name         = "vm_client"
  machine_type = "e2-medium"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-9"
    }
  }

  network_interface {
    network = google_compute_network.vpc_network_1.name
  }
}


##### VM Server Creation
resource "google_compute_instance" "vm_2" {
  provider     = google-beta
  name         = "vm_server"
  machine_type = "e2-medium"
  metadata_startup_script = <<-EOF
    #! /bin/bash
    apt update
    apt -y install apache2
    service apache2 start
    cat <<EOF > /var/www/html/index.html
    <html><body><p>Hi Vivacity this is my Hello World page !</p></body></html>"
    EOF

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-9"
    }
  }

  network_interface {
    network = google_compute_network.vpc_network_2.name
  }
}
