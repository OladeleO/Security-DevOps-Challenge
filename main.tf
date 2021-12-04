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

resource "google_compute_network" "vpc_network_1" {
  project                 = var.project
  name                    = "vpc-server-github-actions"
  mtu                     = 1460
}

resource "google_compute_network" "vpc_network_2" {
  project                 = var.project
  name                    = "vpc-client-github-actions"
  mtu                     = 1460
}


resource "google_compute_subnetwork" "public-subnetwork_1" {
  name          = "subnet-server-github-actions"
  ip_cidr_range = "10.10.10.0/24"
  region        = "europe-west1"
  network       = google_compute_network.vpc_network_1.name
}


resource "google_compute_subnetwork" "public-subnetwork_2" {
  name          = "subnet-client-github-actions"
  ip_cidr_range = "192.168.1.0/24"
  region        = "europe-west2"
  network       = google_compute_network.vpc_network_2.name
}
