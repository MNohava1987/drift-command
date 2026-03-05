terraform {
  required_version = ">= 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }

  # Uncomment and configure when you have a GCP project:
  # backend "gcs" {
  #   bucket = "drift-command-tfstate-dev"
  #   prefix = "terraform/state"
  # }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "region" {
  type    = string
  default = "us-central1"
}

variable "github_repo" {
  type    = string
  default = "MNohava1987/drift-command"
}

module "service_accounts" {
  source     = "../../modules/service_accounts"
  project_id = var.project_id
}

module "artifact_registry" {
  source        = "../../modules/artifact_registry"
  project_id    = var.project_id
  location      = var.region
  repository_id = "drift-command-dev"
}

module "config_bucket" {
  source       = "../../modules/storage_bucket"
  project_id   = var.project_id
  bucket_name  = "${var.project_id}-drift-command-config-dev"
  public_read  = true
}

module "tfstate_bucket" {
  source      = "../../modules/storage_bucket"
  project_id  = var.project_id
  bucket_name = "${var.project_id}-drift-command-tfstate-dev"
  public_read = false
}

module "wif_github" {
  source                = "../../modules/wif_github"
  project_id            = var.project_id
  github_repo           = var.github_repo
  service_account_email = module.service_accounts.github_actions_sa_email

  depends_on = [module.service_accounts]
}

output "artifact_registry_url" {
  value = module.artifact_registry.repository_url
}

output "workload_identity_provider" {
  value = module.wif_github.workload_identity_provider
}
