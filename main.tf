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
  subnets = [
     {
            subnet_name           = "subnet-server-github-actions"
            subnet_ip             = "10.10.10.0/24"
            subnet_region         = "europe-west1"
     }
  ]
}

resource "google_compute_network" "vpc_network_2" {
  project                 = var.project
  name                    = "vpc-client-github-actions"
  mtu                     = 1460
  subnets = [
      {
            subnet_name           = "subnet-client-github-actions"
            subnet_ip             = "192.168.1.0/24"
            subnet_region         = "europe-west2"
      }
   ]
}

