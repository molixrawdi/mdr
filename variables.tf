variable "project_id" {
  description = "Google Cloud project ID"
}

variable "region" {
  default = "us-central1"
}

variable "container_image" {
  description = "Container image for Cloud Run"
}
