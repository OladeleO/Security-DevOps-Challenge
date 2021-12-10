variable "project" {
  default = {{secrets.GCP_PROJECT_ID}}
  senstive = true 
}

variable "region" {
  default = "europe-west1"
  sensitive = true
}

variable "zone" {
  default = "europe-west1-b"
  sensitive = true
}

