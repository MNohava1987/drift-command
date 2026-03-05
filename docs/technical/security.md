# Security Architecture — Drift Command

---

## 1. Principles

1. **No secrets in the mobile client** — the APK/IPA is a public artifact
2. **No long-lived GCP keys in GitHub** — use OIDC instead
3. **Offline-first core** — minimizing backend surface reduces attack surface
4. **Least privilege** — every service account has only what it needs
5. **No unauthenticated admin APIs** — backend write APIs are not public

---

## 2. Client Security

### What the game client must NOT contain

- GCP service account keys
- API keys for any cloud service
- Admin credentials
- Any secret that grants write access to backend systems

### What the game client CAN contain

- Read-only config (baked-in defaults, tuned before release)
- Scenario data (not sensitive)
- Anonymous device ID for telemetry (no PII)

### Remote config fetch (if used)

- Client fetches public scenario/config from Cloud Storage
- GCS bucket is **publicly readable**, no auth required for GET
- Only write access (uploads) requires auth — never exposed to client

---

## 3. GitHub → GCP Authentication

### Pattern: OIDC + Workload Identity Federation

GitHub Actions authenticates to GCP **without storing any GCP credentials in GitHub**.

```
┌─────────────────────────────────────┐
│  GitHub Actions Runner              │
│                                     │
│  1. Request OIDC token from GitHub  │
│     (token contains repo, branch,   │
│      workflow claims)               │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│  GCP Workload Identity Pool         │
│                                     │
│  2. Validate token against pool     │
│     conditions:                     │
│     - repo == MNohava1987/drift-command │
│     - ref == refs/heads/main        │
│                                     │
│  3. Issue short-lived access token  │
│     for bound service account       │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│  GCP Service Account                │
│  (deploy-sa@project.iam...)         │
│                                     │
│  Permissions:                       │
│  - Artifact Registry Writer         │
│  - Cloud Run Developer              │
│  - Storage Object Creator           │
└─────────────────────────────────────┘
```

### Required GitHub secrets (non-sensitive values)

| Secret | Value | Sensitive? |
|---|---|---|
| `GCP_PROJECT_ID` | GCP project ID | No (but kept in secrets for convenience) |
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | WIF provider resource name | No |
| `GCP_SERVICE_ACCOUNT` | SA email | No |

**No service account JSON key is stored anywhere.**

---

## 4. Service Account Design

### Principle: separate identities per function

| Service Account | Purpose | Permissions |
|---|---|---|
| `github-actions-sa` | CI/CD deploys | AR Writer, Cloud Run Developer, Storage Creator |
| `admin-api-sa` | admin-api Cloud Run runtime | Storage Admin (bucket-scoped), Logging Writer |
| `telemetry-api-sa` | telemetry-api Cloud Run runtime | Pub/Sub Publisher or Storage Creator (telemetry bucket only) |

No cross-account permission bleed.

---

## 5. Backend API Security

### admin-api

- Protected by **GCP Identity-Aware Proxy** or **Cloud Run internal-only ingress**
- Not exposed to the public internet for write operations
- Read endpoints (scenario distribution) can be GCS direct — no API needed

### telemetry-api

- Accepts anonymous events (no PII)
- Rate-limited by Cloud Armor or Cloud Run concurrency limits
- No authentication required from client (anonymous telemetry)
- Write-only — no read path exposed to client

---

## 6. Infrastructure Security (Terraform)

All infrastructure is defined in code. No manual GCP console changes:

- IAM bindings are explicit in Terraform
- No wildcard IAM roles (`roles/owner`, `roles/editor`)
- VPC Service Controls considered for prod environment (post-MVP)
- Cloud Storage buckets: uniform bucket-level access, no legacy ACLs
- Cloud Run services: minimum required IAM, not `allUsers` except where read-only public config intended

---

## 7. MVP Security Checklist

Before M5 delivery:

- [ ] Flutter app contains no hardcoded keys or credentials
- [ ] APK built in CI does not include any `.env` files
- [ ] GitHub Actions uses WIF — no `GOOGLE_APPLICATION_CREDENTIALS` JSON in secrets
- [ ] GCS bucket for public config is read-only public, write requires SA auth
- [ ] admin-api is not reachable from public internet without auth
- [ ] All SA roles are least-privilege (no `roles/owner` or `roles/editor`)
- [ ] Terraform state is stored in a private GCS bucket (not public)
- [ ] Branch protection enabled on `main` in GitHub
- [ ] No secrets committed to repo (use `git-secrets` or equivalent pre-commit hook)
