# Infra Setup Runbook

One-time setup to get the GCP project and Terraform state ready. Run this before
your first `terraform apply` and before configuring GitHub secrets.

---

## 1. Create a GCP Project

```bash
gcloud projects create YOUR_PROJECT_ID --name="Drift Command"
gcloud config set project YOUR_PROJECT_ID
```

Link a billing account (required for most APIs):

```bash
gcloud billing projects link YOUR_PROJECT_ID \
  --billing-account=YOUR_BILLING_ACCOUNT_ID
```

---

## 2. Enable Required APIs

Run the helper script (or copy the commands manually):

```bash
bash tools/scripts/gcp-setup.sh YOUR_PROJECT_ID
```

APIs enabled:
- `run.googleapis.com` — Cloud Run (future backend)
- `artifactregistry.googleapis.com` — Docker image registry
- `iam.googleapis.com` — Service accounts & roles
- `storage.googleapis.com` — Cloud Storage (Terraform state)
- `cloudresourcemanager.googleapis.com` — Project resource management
- `iamcredentials.googleapis.com` — Workload Identity Federation (OIDC)

---

## 3. Create a Terraform State Bucket

```bash
gsutil mb -p YOUR_PROJECT_ID -l us-central1 \
  gs://YOUR_PROJECT_ID-tfstate
gsutil versioning set on gs://YOUR_PROJECT_ID-tfstate
```

---

## 4. Fill in tfvars

```bash
cd infra/envs/dev
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
project_id           = "YOUR_PROJECT_ID"
region               = "us-central1"
github_owner         = "YOUR_GITHUB_USERNAME"
github_repo          = "drift-command"
artifact_registry_id = "drift-command"
```

Also update the `backend "gcs"` block in `main.tf` to point at your state bucket:

```hcl
backend "gcs" {
  bucket = "YOUR_PROJECT_ID-tfstate"
  prefix = "infra/dev"
}
```

---

## 5. Terraform Init & Apply

```bash
cd infra/envs/dev
terraform init
terraform plan   # review — should show creates only
terraform apply
```

---

## 6. Collect Outputs for GitHub Secrets

```bash
terraform output
```

Add the following secrets in **GitHub → Settings → Secrets → Actions**:

| Secret name                        | Where to get it                        |
|------------------------------------|----------------------------------------|
| `GCP_PROJECT_ID`                   | Your project ID string                 |
| `GCP_WORKLOAD_IDENTITY_PROVIDER`   | `workload_identity_provider` output    |
| `GCP_SERVICE_ACCOUNT`              | `service_account_email` output         |

After adding secrets, push any commit to `main` to trigger `infra-plan`.

---

## Troubleshooting

- **"API not enabled"** — run `gcp-setup.sh` again or enable the API via the console.
- **"Billing account not linked"** — link a billing account before enabling APIs.
- **`terraform apply` fails on WIF** — ensure `iamcredentials.googleapis.com` is enabled.
- **GitHub Actions OIDC error** — verify `github_owner` and `github_repo` match exactly.
