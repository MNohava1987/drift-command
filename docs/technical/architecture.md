# Technical Architecture — Drift Command

---

## 1. Overview

Drift Command is a **mostly-local, offline-capable mobile game**. The core game runs entirely on device. Backend services are optional and minimal, used only for admin tooling, remote config, and telemetry.

```
┌──────────────────────────────────────────────────────┐
│                  Mobile Device                        │
│                                                       │
│   ┌─────────────────────────────────────────────┐    │
│   │           Flutter + Flame App               │    │
│   │                                             │    │
│   │  ┌──────────┐  ┌──────────┐  ┌──────────┐  │    │
│   │  │  Battle  │  │ Command  │  │  Tempo   │  │    │
│   │  │   Sim   │  │  Model   │  │  System  │  │    │
│   │  └──────────┘  └──────────┘  └──────────┘  │    │
│   │  ┌──────────┐  ┌──────────┐  ┌──────────┐  │    │
│   │  │   Ship  │  │    AI    │  │   UI /   │  │    │
│   │  │  Model  │  │ Doctrine │  │  Touch   │  │    │
│   │  └──────────┘  └──────────┘  └──────────┘  │    │
│   │                                             │    │
│   │         Local save (shared_preferences)     │    │
│   └─────────────────────────────────────────────┘    │
│                       │                               │
│              optional │ HTTPS                         │
└──────────────────────────────────────────────────────┘
                        │
         ┌──────────────▼──────────────┐
         │     GCP (optional backend)  │
         │                             │
         │  Cloud Run (admin-api)      │
         │  Cloud Run (telemetry-api)  │
         │  Cloud Storage (config)     │
         │  Artifact Registry (imgs)   │
         └─────────────────────────────┘
```

---

## 2. Game Client Architecture

### Framework

- **Flutter** — Google's mobile-first UI framework
- **Flame** — 2D game engine built on Flutter
- **Dart** — strongly-typed, class-based language

### Why Flutter + Flame

| Requirement | Flutter + Flame fit |
|---|---|
| Mobile-first | Flutter is designed for mobile from the ground up |
| Offline-capable | No network dependency for core game loop |
| Standard CI/CD | `flutter build apk`, `flutter test` — standard CLI |
| Testable game logic | Pure Dart unit tests, no game engine runner required |
| Code-first dev | No heavy visual editor required, VS Code works fine |

### Module Boundaries

```
game-client/lib/
  core/
    models/          # Ship, weapon, scenario data (pure Dart)
    systems/         # Game loop systems (simulation, command, tempo, combat)
    ai/              # Doctrine-driven AI behaviors
    services/        # Save/load, optional remote config fetch
  ui/
    screens/         # Battle screen, scenario select, results
    widgets/         # HUD, unit cards, command strip, overlays
    painters/        # Custom canvas rendering for tactical map
  data/
    scenarios/       # JSON scenario definitions
    ships/           # Ship role definitions (JSON or Dart constants)
  main.dart
```

### Key Design Rules

1. **`core/` has no Flutter UI dependencies** — pure Dart business logic
2. **`core/systems/` is fully unit-testable** without Flame or Flutter test
3. **Data definitions live in `data/`** — not hardcoded in logic
4. **No network calls in `core/`** — network is only in `core/services/`
5. **`ui/` depends on `core/`**, never the reverse

---

## 3. Game Systems Architecture

### 3.1 Ship Model

```dart
class ShipData {
  final String id;
  final ShipRole role;
  final MassClass massClass;
  final double maxAcceleration;     // units/sec²
  final double turnRate;            // radians/sec
  final double commandLatencyMod;   // multiplier on base propagation delay
  final double sensorRange;
  final double weaponRange;
  final double maxDurability;
  final List<WeaponMount> weapons;
}

class ShipState {
  Vector2 position;
  Vector2 velocity;
  double heading;                   // radians
  double durability;
  String? assignedCommandNodeId;
  OrderQueue pendingOrders;
  Doctrine activeDoctrine;
}
```

### 3.2 Command Model

Order propagation is **timer-based**, not teleported:

```
Player issues order at T=0
  → Order leaves flagship at T=0
  → Order arrives at command ship at T = distance / propagationSpeed
  → Command ship fans order to assigned units at T = T_relay + local_delay
  → Unit begins executing at T = T_unit_receive
```

If the relay chain is broken (command ship destroyed or out of range):
- Units fall back to their assigned `Doctrine`
- Doctrine behaviors: Hold, Engage, Retreat, Screen

### 3.3 Tempo System

```dart
enum TempoBand { distant, contact, engaged }

class TempoSystem {
  TempoBand currentBand;
  double commandPulseSeconds;  // varies by band

  TempoBand evaluate(BattleState state) {
    // based on minimum enemy distance, weapon ranges, active fire
  }
}
```

| Band | Trigger condition | Pulse window |
|---|---|---|
| Distant | All enemies beyond 2× weapon range | 10–20 sec |
| Contact | Any enemy within 2× weapon range | 5–10 sec |
| Engaged | Active weapons fire occurring | 2–5 sec |

### 3.4 Combat System

MVP combat is intentionally simple:

- Ships auto-fire when target is in `weaponRange` and within firing arc
- Weapon categories: direct fire, missiles, point defense
- Defense: armor/hull HP, point defense interception rate
- No manual targeting — doctrine and assignment drive targeting

---

## 4. Backend Architecture (Optional / Minimal)

**The game does not require the backend to function.**

Backend is justified only for:
- Remote scenario/config distribution
- Gameplay telemetry ingestion
- Admin tooling

### Services

| Service | Runtime | Purpose |
|---|---|---|
| `admin-api` | Cloud Run | Scenario uploads, config pushes |
| `telemetry-api` | Cloud Run | Ingest anonymous play events |

Both are:
- Stateless
- Scale-to-zero (Cloud Run request-driven)
- Authenticated (not public write APIs)

### Data Storage

| Resource | Purpose |
|---|---|
| Cloud Storage bucket | Scenario configs, remote tuning |
| Artifact Registry | Container images for Cloud Run services |

---

## 5. Infrastructure Architecture

### Terraform Module Map

```
infra/
  envs/
    dev/          # dev environment root, calls modules
    prod/         # prod environment root
  modules/
    artifact_registry/    # Docker image registry
    cloud_run_service/    # Reusable Cloud Run service module
    storage_bucket/       # GCS bucket
    service_accounts/     # Per-service SA with least privilege
    wif_github/           # Workload Identity Federation for GitHub Actions
```

### GCP Auth Pattern

GitHub Actions authenticates to GCP using **OIDC + Workload Identity Federation**:

```
GitHub Actions runner
  → requests OIDC token from GitHub
  → exchanges token with GCP WIF
  → receives short-lived GCP access token
  → uses token to deploy (no SA key stored anywhere)
```

No long-lived service account JSON keys are stored in GitHub Secrets.

---

## 6. CI/CD Architecture

### GitHub Actions Workflows

| Workflow | Trigger | Actions |
|---|---|---|
| `flutter-ci.yml` | PR to main | `flutter analyze`, `flutter test` |
| `infra-plan.yml` | PR touching `infra/` | `terraform fmt`, `terraform validate`, `terraform plan` |
| `infra-apply.yml` | Push to main (infra changed) | `terraform apply` (requires approval) |
| `android-build.yml` | Push to main or tag | `flutter build apk` (debug for now) |

### Branch Strategy

- `main` — production-ready, protected
- `feature/*` — all development work
- PRs required for merge to `main`
- Conventional commits recommended (not enforced in MVP)

---

## 7. Local Development Setup

### Flutter Development

```bash
# Verify Flutter
flutter doctor

# Get dependencies
cd game-client && flutter pub get

# Run on connected device
flutter run

# Run tests
flutter test

# Analyze
flutter analyze
```

### Terraform Development

```bash
cd infra/envs/dev
terraform init -backend=false   # local plan without remote state
terraform plan
```

---

## 8. Determinism and Testability

A core architectural requirement:

- **Battle simulation is deterministic given the same seed and inputs**
- All game logic in `core/` is pure Dart with no side effects
- `flutter test` runs game logic tests without a device or emulator
- Flame-specific code (rendering, input) lives only in `ui/`

This makes it possible to run thousands of battle simulations in CI and catch balance/logic regressions without a device.
