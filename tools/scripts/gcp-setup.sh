#!/usr/bin/env bash
# Enable all GCP APIs required for Drift Command infra.
# Usage: bash tools/scripts/gcp-setup.sh YOUR_PROJECT_ID

set -euo pipefail

PROJECT_ID="${1:-}"

if [[ -z "$PROJECT_ID" ]]; then
  echo "Usage: $0 <project-id>" >&2
  exit 1
fi

echo "Enabling APIs for project: $PROJECT_ID"

gcloud services enable \
  run.googleapis.com \
  artifactregistry.googleapis.com \
  iam.googleapis.com \
  storage.googleapis.com \
  cloudresourcemanager.googleapis.com \
  iamcredentials.googleapis.com \
  --project="$PROJECT_ID"

echo "Done. All required APIs are enabled."
