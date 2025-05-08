provider "google" {
  project = var.project_id
  region  = var.region
}

# Variables
variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The region to deploy resources"
  type        = string
  default     = "us-central1"
}

variable "service_name" {
  description = "Name of the Cloud Run service"
  type        = string
  default     = "mdr-service"
}

variable "container_image" {
  description = "Container image to deploy"
  type        = string
  default     = "gcr.io/PROJECT_ID/mdr-service:latest"  # Replace with your actual image
}

# Cloud Run service
resource "google_cloud_run_service" "mdr_service" {
  name     = var.service_name
  location = var.region

  template {
    spec {
      containers {
        image = var.container_image
        resources {
          limits = {
            memory = "512Mi"
            cpu    = "1000m"
          }
        }
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }
}

# Make the Cloud Run service publicly accessible
resource "google_cloud_run_service_iam_member" "public_access" {
  service  = google_cloud_run_service.mdr_service.name
  location = google_cloud_run_service.mdr_service.location
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# API Gateway API
resource "google_api_gateway_api" "api" {
  provider = google
  api_id   = "mdr-api"
  display_name = "MDR API Gateway"
}

# API Gateway API Config
resource "google_api_gateway_api_config" "api_config" {
  provider      = google
  api           = google_api_gateway_api.api.api_id
  api_config_id = "mdr-api-config-${formatdate("YYYYMMDDhhmmss", timestamp())}"
  display_name  = "MDR API Config"

  openapi_documents {
    document {
      path = "spec.yaml"
      contents = base64encode(<<-EOT
        swagger: '2.0'
        info:
          title: MDR API Gateway
          description: API Gateway for MDR Service
          version: 1.0.0
        schemes:
          - https
        produces:
          - application/json
        paths:
          /api/mrd:
            get:
              summary: MDR service endpoint
              operationId: mdr-service
              x-google-backend:
                address: ${google_cloud_run_service.mdr_service.status[0].url}
              responses:
                '200':
                  description: OK
            post:
              summary: MDR service endpoint
              operationId: mdr-service-post
              x-google-backend:
                address: ${google_cloud_run_service.mdr_service.status[0].url}
              responses:
                '200':
                  description: OK
      EOT
      )
    }
  }

  gateway_config {
    backend_config {
      google_service_account = "SERVICE_ACCOUNT_EMAIL"  # Replace with your service account email
    }
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [google_api_gateway_api.api]
}

# API Gateway
resource "google_api_gateway_gateway" "gateway" {
  provider     = google
  region       = var.region
  api_config   = google_api_gateway_api_config.api_config.id
  gateway_id   = "mdr-gateway"
  display_name = "MDR Gateway"

  depends_on = [google_api_gateway_api_config.api_config]
}

# Load Balancer with external IP
# Reserve an external IP
resource "google_compute_global_address" "mdr_lb_ip" {
  name = "mdr-lb-ip"
}

# Create HTTPS certificate
resource "google_compute_managed_ssl_certificate" "mdr_cert" {
  name = "mdr-ssl-cert"
  managed {
    domains = ["example.com"]  # Replace with your actual domain
  }
}

# HTTP to HTTPS redirect
resource "google_compute_url_map" "https_redirect" {
  name = "mdr-https-redirect"

  default_url_redirect {
    https_redirect         = true
    redirect_response_code = "MOVED_PERMANENTLY_DEFAULT"
    strip_query            = false
  }
}

# HTTP Target Proxy
resource "google_compute_target_http_proxy" "http_proxy" {
  name    = "mdr-http-proxy"
  url_map = google_compute_url_map.https_redirect.id
}

# HTTP Forwarding Rule
resource "google_compute_global_forwarding_rule" "http_forwarding_rule" {
  name       = "mdr-http-rule"
  target     = google_compute_target_http_proxy.http_proxy.id
  port_range = "80"
  ip_address = google_compute_global_address.mdr_lb_ip.address
}

# URL Map for HTTPS
resource "google_compute_url_map" "url_map" {
  name            = "mdr-url-map"
  default_service = google_compute_backend_service.api_gateway_backend.id

  host_rule {
    hosts        = ["example.com"]  # Replace with your actual domain
    path_matcher = "mdr-paths"
  }

  path_matcher {
    name            = "mdr-paths"
    default_service = google_compute_backend_service.api_gateway_backend.id

    path_rule {
      paths   = ["/api/example.com/api/mrd", "/api/example.com/api/mrd/*"]
      service = google_compute_backend_service.api_gateway_backend.id
    }
  }
}

# HTTPS Target Proxy
resource "google_compute_target_https_proxy" "https_proxy" {
  name             = "mdr-https-proxy"
  url_map          = google_compute_url_map.url_map.id
  ssl_certificates = [google_compute_managed_ssl_certificate.mdr_cert.id]
}

# HTTPS Forwarding Rule
resource "google_compute_global_forwarding_rule" "https_forwarding_rule" {
  name       = "mdr-https-rule"
  target     = google_compute_target_https_proxy.https_proxy.id
  port_range = "443"
  ip_address = google_compute_global_address.mdr_lb_ip.address
}

# Network Endpoint Group for API Gateway
resource "google_compute_global_network_endpoint_group" "api_gateway_neg" {
  name                  = "mdr-api-gateway-neg"
  network_endpoint_type = "INTERNET_FQDN_PORT"
  default_port          = 443
}

# Network endpoint for API Gateway
resource "google_compute_global_network_endpoint" "api_gateway_endpoint" {
  global_network_endpoint_group = google_compute_global_network_endpoint_group.api_gateway_neg.name
  fqdn                          = regex("^https://([^/]+)/", google_api_gateway_gateway.gateway.default_hostname)[0]
  port                          = 443
}

# Backend service for API Gateway
resource "google_compute_backend_service" "api_gateway_backend" {
  name        = "mdr-api-gateway-backend"
  protocol    = "HTTPS"
  timeout_sec = 30
  enable_cdn  = false

  backend {
    group = google_compute_global_network_endpoint_group.api_gateway_neg.id
  }
}

# Outputs
output "cloud_run_url" {
  value = google_cloud_run_service.mdr_service.status[0].url
}

output "api_gateway_url" {
  value = google_api_gateway_gateway.gateway.default_hostname
}

output "load_balancer_ip" {
  value = google_compute_global_address.mdr_lb_ip.address
}
