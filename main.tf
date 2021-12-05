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
  name         = "vm-client"
  machine_type = "e2-medium"
  zone         = "europe-west1-b" 

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-9"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.public-subnetwork_1.name
  }
}


##### VM Server Creation
resource "google_compute_instance" "vm_2" {
  provider     = google-beta
  name         = "vm-server"
  machine_type = "e2-medium"
  zone         = "europe-west2-b"
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
    subnetwork = google_compute_subnetwork.public-subnetwork_2.name
  }
}

############ Ping before VPN ?

##### VPN Creation
resource "google_compute_vpn_gateway" "target_gateway_client" {
  name    = "vpn-gateway-client-terraform"
  #network = google_compute_subnetwork.public-subnetwork_1.id
  network = google_compute_network.vpc_network_1.name
}

resource "google_compute_vpn_gateway" "target_gateway_server" {
  name    = "vpn-gateway-server-terraform"
  #network = google_compute_subnetwork.public-subnetwork_2.id
  network = google_compute_network.vpc_network_1.name
}

resource "google_compute_address" "vpn_static_ip_client" {
  name = "vpn-static-ip-client-terraform" 
}

resource "google_compute_address" "vpn_static_ip_server" {
  name = "vpn-static-ip-server-terraform"
}

resource "google_compute_forwarding_rule" "fr_esp" {
  name        = "fr-esp"
  ip_protocol = "ESP"
  ip_address  = google_compute_address.vpn_static_ip_client.address
  target      = google_compute_vpn_gateway.target_gateway_client.id
}

resource "google_compute_forwarding_rule" "fr_udp500" {
  name        = "fr-udp500"
  ip_protocol = "UDP"
  port_range  = "500"
  ip_address  = google_compute_address.vpn_static_ip_client.address
  target      = google_compute_vpn_gateway.target_gateway_client.id
}

resource "google_compute_forwarding_rule" "fr_udp4500" {
  name        = "fr-udp4500"
  ip_protocol = "UDP"
  port_range  = "4500"
  ip_address  = google_compute_address.vpn_static_ip_client.address
  target      = google_compute_vpn_gateway.target_gateway_client.id
}

#######################################################################


resource "google_compute_vpn_tunnel" "tunnel_client_to_server" {
  name          = "tunnel_client_to_server"
  peer_ip       = google_compute_address.vpn_static_ip_client.address
  shared_secret = "gcprocks"
  local_traffic_selector = ["10.10.10.0/24"]
  remote_traffic_selector = ["192.168.1.0/24"]

  target_vpn_gateway = google_compute_vpn_gateway.target_gateway_client.id

  depends_on = [
    google_compute_forwarding_rule.fr_esp,
    google_compute_forwarding_rule.fr_udp500,
    google_compute_forwarding_rule.fr_udp4500,
  ]
}

resource "google_compute_vpn_tunnel" "tunnel_server_to_client" {
  name          = "tunnel_client_to_server"
  peer_ip       = google_compute_address.vpn_static_ip_server.address
  shared_secret = "gcprocks"
  local_traffic_selector = ["192.168.1.0/24"]
  remote_traffic_selector = ["10.10.10.0/24"]

  target_vpn_gateway = google_compute_vpn_gateway.target_gateway_server.id

  depends_on = [
    google_compute_forwarding_rule.fr_esp,
    google_compute_forwarding_rule.fr_udp500,
    google_compute_forwarding_rule.fr_udp4500,
  ]
}

resource "google_compute_route" "route_client_to_server" {
  name       = "route1"
  network    = google_compute_subnetwork.public-subnetwork_1.id
  dest_range = google_compute_subnetwork.public-subnetwork_2.ip_cidr_range
  priority   = 1000

  next_hop_vpn_tunnel = google_compute_vpn_tunnel.tunnel_client_to_server.id
}

resource "google_compute_route" "route_server_to_client" {
  name       = "route1"
  network    = google_compute_subnetwork.public-subnetwork_2.id
  dest_range = google_compute_subnetwork.public-subnetwork_1.ip_cidr_range
  priority   = 1000

  next_hop_vpn_tunnel = google_compute_vpn_tunnel.tunnel_server_to_client.id
}
 ###########################################################################
