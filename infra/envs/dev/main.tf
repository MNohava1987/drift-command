terraform {
  required_version = ">= 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }

  backend "gcs" {
    bucket = "drift-command-drift-command-tfstate-dev"
    prefix = "terraform/state"
  }
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

# Give github-actions-sa full object-level access to the tfstate bucket
# so Terraform init/plan/apply can read, write, and delete the state lock.
resource "google_storage_bucket_iam_member" "github_actions_tfstate" {
  bucket = module.tfstate_bucket.bucket_name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${module.service_accounts.github_actions_sa_email}"

  depends_on = [module.service_accounts, module.tfstate_bucket]
}

output "artifact_registry_url" {
  value = module.artifact_registry.repository_url
}

output "workload_identity_provider" {
  value = module.wif_github.workload_identity_provider
}
