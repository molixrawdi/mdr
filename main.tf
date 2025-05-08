provider "google" {
  project = var.project_id
  region  = var.region
}

# Enable necessary APIs
resource "google_project_service" "required_apis" {
  for_each = toset([
    "run.googleapis.com",
    "apigateway.googleapis.com",
    "compute.googleapis.com",
    "servicemanagement.googleapis.com",
    "servicemanagement.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com"
  ])
  service = each.key
}

# Create Cloud Run service
resource "google_cloud_run_service" "mdr" {
  name     = "mdr-service"
  location = var.region

  template {
    spec {
      containers {
        image = var.container_image
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }
}

# Allow unauthenticated invocations
resource "google_cloud_run_service_iam_member" "noauth" {
  location = google_cloud_run_service.mdr.location
  service  = google_cloud_run_service.mdr.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# API Gateway Config
resource "google_api_gateway_api" "mdr_api" {
  api_id = "mdr-api"
}

resource "google_api_gateway_api_config" "mdr_config" {
  api      = google_api_gateway_api.mdr_api.api_id
  config_id = "mdr-config"

  openapi_documents {
    document {
      path     = "openapi.yaml"
      contents = file("openapi.yaml")
    }
  }

  depends_on = [google_cloud_run_service.mdr]
}

resource "google_api_gateway_gateway" "mdr_gateway" {
  name     = "mdr-gateway"
  api      = google_api_gateway_api.mdr_api.api_id
  api_config = google_api_gateway_api_config.mdr_config.id
  location = var.region
}
