# MVP Build Plan — Drift Command

**Version:** 1.0
**Engine:** Flutter + Flame
**Platform:** Mobile-first (Android primary, iOS-compatible)
**Delivery:** AI-assisted development via GitHub + GCP

---

## 1. Executive Summary

Drift Command is a mobile-first fleet command tactics game built around **momentum, distance, command delay, and role-based ship behavior**.

The player wins through:
- committing to approach vectors
- understanding turning inertia
- using command ships correctly
- timing orders across distance
- countering enemy tempo with the right ship mix

**The game feels like chess in space under communication delay.**

This MVP focuses on a single-player tactical battle loop with a small number of ship roles, a readable mobile UI, and a limited set of scenarios. It deliberately excludes campaign bloat, deep logistics trees, and multiplayer.

---

## 2. Core Design Promises

| Pillar | Description |
|---|---|
| Momentum is commitment | Ships cannot instantly stop, pivot, or click-turn |
| Orders take time | Commands propagate across distance, not instantly |
| Command ships matter | Flagship and relays are not just units — they are control topology |
| Tempo emerges from distance | Long range = deliberate; close engagement = compressed and lethal |
| Roles create counterplay | No ship class is universally dominant |

---

## 3. MVP Scope

### In Scope

- Single-player tactical encounters
- Mobile-first touch controls
- 6 ship roles
- Command hierarchy (flagship → relay → combat ships)
- Communication delay system
- Momentum / turn commitment kinematics
- Adaptive battle tempo (3 bands)
- Basic doctrine-driven AI opponent
- Scenario-based missions (3 scenarios)
- Local save data on device
- Optional minimal cloud backend (admin/config/telemetry only)

### Out of Scope (MVP)

- Full campaign map
- Persistent fleet resource simulation
- Complex manufacturing or economy trees
- Boarding / marine micro
- Multiplayer (any form)
- Live service / gacha / F2P systems
- PC build optimization
- Real-time PvP synchronization

---

## 4. Core Gameplay Loop

### Match Flow

1. Player enters scenario → reviews battlefield and command topology
2. Player issues orders from flagship / command nodes
3. Orders travel to command ships, then to assigned combat units
4. Ships execute based on: velocity, turn rate, mass class, current doctrine
5. Enemy reacts via its own command structure and AI doctrine
6. Battle state transitions from long-range maneuver → close engagement
7. Win/loss determined by objective state

### Session Targets

| Target | Value |
|---|---|
| Battle length | 5–12 minutes |
| Command cycle (distant) | 10–20 seconds (simulated) |
| Command cycle (contact) | 5–10 seconds |
| Command cycle (engaged) | 2–5 seconds |

---

## 5. Command and Communication Model

### Command Hierarchy

```
Admiral Ship (Flagship)
    └─ Command Relay Ships
           └─ Line / Combat Ships
                  └─ Independent (degraded) fallback
```

### Order Flow

1. Player issues order at flagship
2. Order propagates toward target command ship at rate based on distance
3. Command ship applies order to its assigned units
4. If relay chain is disrupted, units fall back to doctrine behavior

### Effects of Communication Delay

- Longer distance = slower order arrival
- Better relay positioning = tighter response
- Destroying command ships causes: delayed reactions, degraded formations, possible unit isolation

---

## 6. Kinematics Model

**Stylized simulation — not full Newtonian physics.**

Each ship carries:

```
velocity              Vector2   current movement vector
maxAcceleration       double    thrust capability
turnRate              double    radians/second
massClass             enum      determines response lag
commandLatencyMod     double    per-unit delay modifier
sensorRange           double
weaponRange           double
durability            double
roleTags              List<RoleTag>
```

### Rules

- Ships continue on current vector until thrust changes are applied
- Direction changes require real time (turn commitment cost)
- Heavier ships have lower maneuver responsiveness
- High-speed commitment creates risk during approach
- Repositioning is a tactical cost, not a free action

---

## 7. Adaptive Tempo System

The game does **not** use player camera zoom to control pace. Battle state drives tempo.

| Band | State | Command Window | Interface Focus |
|---|---|---|---|
| A — Distant | Units far apart, low threat | 10–20 sec | Route, vector, spacing |
| B — Contact | Detection achieved, envelopes closing | 5–10 sec | Intercepts, screening, relay |
| C — Engaged | Active exchange | 2–5 sec | Damage, timing, position |

Tempo band is computed from fleet-wide threat state, not player zoom.

---

## 8. Ship Roles (6 MVP Roles)

| Role | Characteristics |
|---|---|
| Flagship | Command origin, high strategic value, loss disrupts fleet |
| Command Relay | Extends command coverage, reduces local delay, fragile but critical |
| Heavy Line Ship | Slow turn, durable, high direct fire, good anchor |
| Light Escort | Fast response, screens heavies, counters fast attackers |
| Strike Carrier | Projects force indirectly, lower direct survivability |
| Fast Raider | High tempo, flanking, relay disruption, countered by prepared defenses |

---

## 9. Combat Resolution (MVP)

Keep it clean for MVP:

- Auto-fire based on range and facing
- Weapon categories: direct fire, missile/strike, point defense
- Defense layers: armor/hull, interception/screening
- No subsystem simulation in MVP

---

## 10. AI Design

Doctrine-driven, not brute-force smart:

- Hold formation
- Screen high-value units
- Focus on relay disruption
- Protect flagship
- Push with fast ships if player overextends
- Fall back if command chain collapses

---

## 11. UX / Mobile Constraints

### Non-Negotiable

- No tiny tap targets
- No drag-box micro as primary control
- No required rapid multi-unit tap spam
- No overloaded HUD

### Control Model

- Tap unit or group → select
- Tap command button → choose action
- Tap destination/target → confirm
- Optional press-and-hold for vector preview
- Command queue: max 2–3 queued orders

### UI Panels

- Top: tempo state + mission objective
- Left/bottom: selected unit card
- Bottom strip: Move / Hold / Screen / Attack / Relay / Retreat
- Overlay: command latency preview / relay coverage visualization

---

## 12. Visual Direction (MVP)

**Readability beats realism.**

- Clean 2D top-down tactical silhouettes
- Strong faction color separation
- Readable range arcs and relay lines
- Dark-space backdrop with restrained FX
- Avoid: high-detail ships, heavy VFX, particle spam, complex damage modeling

---

## 13. MVP Milestones

### M0 — Foundation
- Flutter project initialized, repo structure created
- Branch protections on `main`
- CI: `flutter test` + `flutter analyze` on PR
- Terraform skeleton for GCP resources
- `.gitignore` for Flutter, Dart, Terraform

### M1 — Tactical Sandbox
- One arena
- Two factions
- Flagship + relay ship + heavy + light escort
- Movement vectors and momentum
- Command delay prototype (timer-based propagation)
- Basic direct-fire combat resolution

### M2 — Command Structure
- Full flagship → relay → combat ship chain
- Order propagation logic
- Relay disruption mechanics
- Degraded/disconnected doctrine fallback behavior

### M3 — Tempo System
- Distant / contact / engaged band detection
- Pulse-command loop per band
- UI indicators for tempo state
- Band transitions feel meaningful, not just visual

### M4 — MVP Combat Pack
- All 6 ship roles implemented
- 3 scenarios with distinct objectives
- Win/loss condition logic
- Basic AI doctrine behaviors

### M5 — Delivery Readiness
- Android test build (APK via GitHub Actions)
- Performance pass on mid-range device
- Optional telemetry/admin backend (Cloud Run) if needed
- Security review against criteria
- Complete docs and runbooks

---

## 14. Acceptance Criteria (MVP Done When)

- Player completes a battle on phone in under 12 minutes
- Orders visibly propagate with delay
- Relay ship loss materially impacts fleet control
- Heavy ships feel slower to reorient than light ships
- Tempo clearly shifts across distance bands
- Unit roles create meaningful counterplay
- Game is readable on mobile screen
- App functions offline for core gameplay
- No secrets embedded in the client
- CI/CD can build the app and provision cloud resources without long-lived GCP keys
