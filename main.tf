provider "google" {
   version = "3.53"
   
   
   project = var.project
   region  = var.region
   zone    = var.zone
}

##### Creation VPC Client
resource "google_compute_network" "vpc_network_client" {
  project                 = var.project
  name                    = "vpc-client-github-actions"
  auto_create_subnetworks = false
  mtu                     = 1460
}


##### Creation VPC Server
resource "google_compute_network" "vpc_network_server" {
  project                 = var.project
  name                    = "vpc-server-github-actions"
  auto_create_subnetworks = false 
  mtu                     = 1460
}

##### Subnetwork Client
resource "google_compute_subnetwork" "public_subnetwork_client" {
  name          = "subnet-client-github-actions"
  ip_cidr_range = "10.10.10.0/24"
  region        = "europe-west1"
  network       = google_compute_network.vpc_network_client.name
}

##### Subnetwork Server
resource "google_compute_subnetwork" "public_subnetwork_server" {
  name          = "subnet-server-github-actions"
  ip_cidr_range = "192.168.1.0/24"
  region        = "europe-west2"
  network       = google_compute_network.vpc_network_2.name
}

##### Firewall rule 1st VPC
resource "google_compute_firewall" "default_client" {
  name    = "allow-icmp-ssh"
  network = google_compute_network.vpc_network_client.name

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

##### Firewall rule 2nd VPC
resource "google_compute_firewall" "default_server" {
  name    = "allow-icmp-ssh-http"
  network = google_compute_network.vpc_network_server.name

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["22","80"]
  }
}

##### VM Client Creation
resource "google_compute_instance" "vm_client" {
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
    subnetwork = google_compute_subnetwork.public_subnetwork_client.name
  }
}


##### VM Server Creation
resource "google_compute_instance" "vm_server" {
  provider     = google-beta
  name         = "vm-server"
  machine_type = "e2-medium"
  zone         = "europe-west2-b"
  metadata_startup_script = file("startup_script.sh")
#  metadata     = {
#     startup_script = <<-SCRIPT
#    #! /bin/bash
#    sudo apt update
#    sudo apt -y install apache2
#    sudo service apache2 start
#    sudo echo "<html><body><p>Hi this is my wonderful Hello World page !</p></body></html>" > /var/www/html/index.html 
#    SCRIPT
#     startup_script = "echo hi > /test.txt"
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-9"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.public_subnetwork_server.name
    access_config {}
  }
}

############ Ping before VPN ?

##### VPN Creation
resource "google_compute_vpn_gateway" "target_gateway_client" {
  name    = "vpn-gateway-client-terraform"
  #network = google_compute_subnetwork.public-subnetwork_1.id
  network = google_compute_network.vpc_network_client.name
}

resource "google_compute_vpn_gateway" "target_gateway_server" {
  name    = "vpn-gateway-server-terraform"
  #network = google_compute_subnetwork.public-subnetwork_2.id
  network = google_compute_network.vpc_network_server.name
}

resource "google_compute_address" "vpn_static_ip_client" {
  name = "vpn-static-ip-client-terraform" 
}

resource "google_compute_address" "vpn_static_ip_server" {
  name = "vpn-static-ip-server-terraform"
}

resource "google_compute_forwarding_rule" "fr_esp_client" {
  name        = "fr-esp-client"
  ip_protocol = "ESP"
  ip_address  = google_compute_address.vpn_static_ip_client.address
  target      = google_compute_vpn_gateway.target_gateway_client.id
}

resource "google_compute_forwarding_rule" "fr_udp500_client" {
  name        = "fr-udp500-client"
  ip_protocol = "UDP"
  port_range  = "500"
  ip_address  = google_compute_address.vpn_static_ip_client.address
  target      = google_compute_vpn_gateway.target_gateway_client.id
}

resource "google_compute_forwarding_rule" "fr_udp4500_client" {
  name        = "fr-udp4500-client"
  ip_protocol = "UDP"
  port_range  = "4500"
  ip_address  = google_compute_address.vpn_static_ip_client.address
  target      = google_compute_vpn_gateway.target_gateway_client.id
}

resource "google_compute_forwarding_rule" "fr_esp_server" {
  name        = "fr-esp-server"
  ip_protocol = "ESP"
  ip_address  = google_compute_address.vpn_static_ip_server.address
  target      = google_compute_vpn_gateway.target_gateway_server.id
}

resource "google_compute_forwarding_rule" "fr_udp500_server" {
  name        = "fr-udp500-server"
  ip_protocol = "UDP"
  port_range  = "500"
  ip_address  = google_compute_address.vpn_static_ip_server.address
  target      = google_compute_vpn_gateway.target_gateway_server.id
}

resource "google_compute_forwarding_rule" "fr_udp4500_server" {
  name        = "fr-udp4500-server"
  ip_protocol = "UDP"
  port_range  = "4500"
  ip_address  = google_compute_address.vpn_static_ip_server.address
  target      = google_compute_vpn_gateway.target_gateway_server.id
}

#######################################################################


resource "google_compute_vpn_tunnel" "tunnel_client_to_server" {
  name          = "tunnel-client-to-server"
  peer_ip       = google_compute_address.vpn_static_ip_server.address
  shared_secret = "gcprocks"
  local_traffic_selector = [google_compute_subnetwork.public_subnetwork_client.ip_cidr_range]
  remote_traffic_selector = ["192.168.1.0/24"]

  target_vpn_gateway = google_compute_vpn_gateway.target_gateway_client.id

  depends_on = [
    google_compute_forwarding_rule.fr_esp_client,
    google_compute_forwarding_rule.fr_udp500_client,
    google_compute_forwarding_rule.fr_udp4500_client,
  ]
}

resource "google_compute_vpn_tunnel" "tunnel_server_to_client" {
  name          = "tunnel-server-to-client"
  peer_ip       = google_compute_address.vpn_static_ip_client.address
  shared_secret = "gcprocks"
  local_traffic_selector = ["192.168.1.0/24"]
  remote_traffic_selector = [google_compute_subnetwork.public_subnetwork_client.ip_cidr_range]

  target_vpn_gateway = google_compute_vpn_gateway.target_gateway_server.id

  depends_on = [
    google_compute_forwarding_rule.fr_esp_server,
    google_compute_forwarding_rule.fr_udp500_server,
    google_compute_forwarding_rule.fr_udp4500_server,
  ]
}

resource "google_compute_route" "route_client_to_server" {
  name       = "route-client-to-server"
  network    = google_compute_network.vpc_network_client.name
  dest_range = google_compute_subnetwork.public_subnetwork_server.ip_cidr_range
  priority   = 1000

  next_hop_vpn_tunnel = google_compute_vpn_tunnel.tunnel_client_to_server.id
}

resource "google_compute_route" "route_server_to_client" {
  name       = "route-server-to-client"
  network    = google_compute_network.vpc_network_server.name
  dest_range = google_compute_subnetwork.public_subnetwork_client.ip_cidr_range
  priority   = 1000

  next_hop_vpn_tunnel = google_compute_vpn_tunnel.tunnel_server_to_client.id
}

output "server_public_ip" {
  value = google_compute_instance.vm_2.network_interface.0.access_config.0.nat_ip
}

 ######################################################################################
