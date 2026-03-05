# Drift Command

**Mobile-first fleet command tactics game.**

You are commanding a distributed naval force in space where ships carry momentum, heavier ships react slower, distance creates communication delay, and bad commitments cannot be instantly undone.

The game feels like **chess in space under communication delay**.

---

## Core Loop

1. Enter a tactical scenario
2. Review battlefield state and command topology
3. Issue orders from flagship / command nodes
4. Orders propagate with delay based on distance and relay coverage
5. Ships execute based on velocity, turn rate, mass class, and current doctrine
6. Win by destroying priority targets, surviving, or achieving objective state

---

## Tech Stack

| Layer | Technology |
|---|---|
| Game client | Flutter + Flame |
| Language | Dart |
| Infrastructure | Terraform + GCP |
| Cloud services | Cloud Run, Cloud Storage, Artifact Registry |
| CI/CD | GitHub Actions |
| GCP auth | OIDC / Workload Identity Federation (no long-lived keys) |
| Containerization | Docker (CI tooling only, not the mobile runtime) |

---

## Repository Structure

```
drift-command/
  game-client/          # Flutter + Flame mobile app
  infra/                # Terraform infrastructure
    envs/dev/
    envs/prod/
    modules/
  services/             # Optional minimal backend services
    admin-api/
    telemetry-api/
  docs/
    product/            # Game design and product docs
    technical/          # Architecture and security docs
    runbooks/           # Operational runbooks
  tools/
    ci/                 # CI helper scripts
    scripts/            # Dev utility scripts
  .github/
    workflows/          # GitHub Actions
```

---

## Development Setup

### Prerequisites

- Flutter SDK (installed via snap: `sudo snap install flutter --classic`)
- Android Studio or Android command-line tools (for Android builds)
- Dart (bundled with Flutter)
- Terraform >= 1.5
- GCP project with billing enabled
- GitHub CLI

### Local game development

```bash
cd game-client
flutter pub get
flutter run                  # requires connected device or emulator
flutter test                 # run unit tests
```

### Infrastructure

```bash
cd infra/envs/dev
terraform init
terraform plan
terraform apply
```

---

## Milestones

| Milestone | Description |
|---|---|
| M0 — Foundation | Repo, CI, Terraform skeleton, Flutter scaffold |
| M1 — Tactical Sandbox | One arena, flagship + relay + two ship types, movement, command delay |
| M2 — Command Structure | Order propagation, relay disruption, degraded behavior |
| M3 — Tempo System | Distant / contact / engaged bands, UI indicators |
| M4 — MVP Combat Pack | Six ship roles, three scenarios, AI, win/loss |
| M5 — Delivery | Android test build, performance pass, security review |

---

## Security

- No API keys or secrets embedded in the game client
- No long-lived GCP service account keys in GitHub
- GCP access via GitHub Actions OIDC + Workload Identity Federation
- Backend APIs are unauthenticated surface-free for core gameplay

See [docs/technical/security.md](docs/technical/security.md) for full security architecture.

---

## License

TBD
