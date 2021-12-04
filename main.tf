provider "google" {
   version = "3.53"
   
   
   project = var.project
   region  = var.region
   zone    = var.region
}

#resource "google_container_cluster" "my_vpc_native_cluster" {
#   name                 = var.gke_cluster_name
#   location             = var.zone
#   initial_node_count   = 1
   
#   network              = "default"
#   subnetwork           = "default"
  
#}

resource "google_compute_network" "vpc_network" {
  project                 = "my-project-name"
  name                    = "vpc-server"
  auto_create_subnetworks = true
  mtu                     = 1460
}

resource "google_compute_network" "vpc_network" {
  project                 = "my-project-name"
  name                    = "vpc-client"
  auto_create_subnetworks = true
  mtu                     = 1460
}

