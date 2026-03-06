# Drift Command as Simulation Framework

**Purpose:** This document captures the design intent behind Drift Command as a
simulation-first project — not just a finished game, but a validated foundation
for future, larger-scale projects.

---

## What We Are Actually Building

Drift Command looks like a mobile tactics game. It is also a **test environment** for:

1. Fleet command simulation mechanics that would power a larger game
2. AI doctrine and decision-making architectures that can scale to persistent campaigns
3. A rendering + physics pipeline that can be ported to other platforms
4. Player feedback loops around command delay, momentum, and imperfect information

Every design and architecture decision should pass a secondary test:
**"Would this generalize to a larger game?"**

If a decision is irreversible or creates lock-in that would hurt the next game,
reconsider it.

---

## What the Simulation Validates

### Physics Model

**What we test:** Does stylized Newtonian momentum (not full physics) create
meaningful commitment decisions without frustrating players?

**What we learn:** Whether ships need actual mass simulation or whether
"acceleration time" and "arrival momentum" are sufficient abstractions.
The current model (velocity vector + max acceleration + turn rate) suggests
the latter — players experience the physics without a physics engine.

**Generalizes to:** Any scale of engagement. A capital ship with maxAcceleration=6
feels different from a raider at 38. The same model works at 1:1 scale or 1:1000.

### Command Delay as Mechanic

**What we test:** Does propagation delay feel like a meaningful constraint
or just a frustration mechanic?

**What we learn:** At 2–5 second command windows (engaged tempo), delay is
barely felt but still present. At 10–20 seconds (distant tempo), delay creates
genuine planning pressure. The sweet spot is somewhere in the contact band.

**Generalizes to:** A campaign game where commands propagate across light-minutes
in real space — the same system, different time scales.

### Role Asymmetry

**What we test:** Do ship roles create actual tactical decisions or do players
just spam the strongest unit?

**What we learn:** Whether the counter web (see: game-balance.md) works in practice.
If players discover a dominant strategy that skips the counter web, we learn
which balance knob to tighten.

**Generalizes to:** A larger roster with more hull types, subsystem damage,
electronic warfare, and logistics ships. The RoleTag system is designed to extend
without structural changes.

### Squad Autonomy

**What we test:** At what level of abstraction does the player feel like
a fleet commander rather than a micromanager?

**What we learn:** The M6 squad system answers: one level above individual ships
is the right abstraction. Players feel strategic weight without per-unit control.

**Generalizes to:** Multiplayer. In a larger game, each squad is commanded by
a player — the Admiral's interface remains squads, not ships.

### Doctrine AI

**What we test:** Can a doctrine-based AI (no lookahead, no minimax) create
challenging opponents that feel like they have a coherent strategy?

**What we learn:** Whether posture-based AI (aggressive/defensive/flanking/holdAndFire)
combined with engagement modes (DIRECT/ENGAGE/GHOST) produces emergent behavior
that reads as intelligent.

**Generalizes to:** A larger AI stack where doctrine is the lowest level.
Commander-layer AI sits above doctrine, interpreting intent before issuing squad orders.

---

## The Three-Layer AI Architecture (Future)

The current DoctrineAI is level 1 of a planned 3-layer stack:

```
Layer 3: Campaign AI (strategic, persistent)
   └── Sets faction objectives, theater priorities, resource allocation
   └── Runs between battles, not during them

Layer 2: Commander AI (operational, per-battle)
   └── Interprets Admiral orders through doctrine personality
   └── Makes local decisions about squad deployment and posture
   └── Decision Provider interface — swappable for human players in multiplayer

Layer 1: Doctrine AI (tactical, per-tick) ← CURRENT IMPLEMENTATION
   └── Sets squad posture and engagement mode
   └── Responds to tempo band
   └── Deterministic and testable
```

Drift Command validates Layer 1. It is designed to accept Layer 2 without
architectural changes — `DoctrineAI` is already namespaced to "doctrine," and
the `CommandSystem.issueSquadOrder()` API is the right insertion point for
a Commander layer.

---

## Architecture Decisions Made for Portability

### RoleTag as data, not behavior

`RoleTag` is an enum that the combat system reads. Ship behavior is derived
from tags at runtime, not hardcoded per ship type.

**Why this matters for the next game:** Adding a new ship type means adding
a new ShipData entry with a tag combination. It does not mean writing new
combat logic. The combat system already handles `torpedo` + `directFire` on the
same ship without modification.

### SquadState is the command primitive

Orders go to squads, not ships. Ships follow squads via SquadSystem.
This separates "what the fleet is commanded to do" from "how individual ships execute it."

**Why this matters for the next game:** Multiplayer means multiple players each
controlling squads. The command layer is already squad-scoped. Adding a second
player is an input routing change, not an architecture change.

### ScenarioLoader as the fleet initializer

Battle state is fully described by a JSON file. No state is hard-coded in game logic.

**Why this matters for the next game:** Scenarios, campaign battles, and procedurally
generated engagements all serialize to the same format. A campaign layer that generates
"ambush at coordinates X with enemy fleet Y" writes a JSON file. The game loads it.

### BattleState is the complete simulation state

The entire battle — ships, squads, win conditions, faction postres — is in
one BattleState object. There is no global state. No singletons. No side effects.

**Why this matters for the next game:** BattleState can be serialized,
transmitted over a network, replayed, or forked for AI simulation branches.
This is the foundation for both replay systems and client-server multiplayer.

---

## What the Next Game Looks Like

Based on what Drift Command validates, the logical next game is:

**Working title:** Unnamed persistent campaign game

**Core concept:** The same simulation engine, but:
- Battles are part of a campaign. Winning or losing a battle has persistent consequences.
- Ships destroyed in battle are gone. Replacements cost resources and time.
- Multiple players can fill Commander roles within a single fleet.
- The "Admiral" manages the campaign map — territory, logistics, fleet repair — not individual battles.
- Individual battles are played at the squad-command level Drift Command established.

**What Drift Command proves before we start:**
- [ ] The physics model is readable and fun at mobile resolution
- [ ] The squad abstraction is the right command granularity
- [ ] The counter web creates actual decisions (not dominant strategies)
- [ ] The doctrine AI is good enough for single-player and co-op PvE
- [ ] The data-driven scenario format can generate varied encounter types
- [ ] The codebase can onboard new ship types via data entry (not code changes)

---

## Simulation Fidelity Choices

These are intentional simplifications. They are correct for this game.
Revisit them when building the next game.

| Mechanic | Drift Command (simplified) | Next game (possible) |
|---|---|---|
| Physics | Stylized: accel + turn rate | Full Newtonian + angular momentum |
| Damage | Continuous DPS per frame | Hit detection, armor facings, subsystems |
| Sensor delay | Distance-based linear delay | Sensor profiles, ECM, active vs passive |
| Command delay | Propagation timer | Network topology simulation |
| Ammunition | Infinite | Limited — forces logistics layer |
| Crew | Absent | Morale, casualties, veteran bonuses |
| Time scale | Real time + multiplier | Pausable but async in multiplayer |

---

## What Not to Change

These are the load-bearing decisions of the simulation. Changing them breaks the
"what we tested" claims above.

1. **Momentum is real** — ships cannot teleport or instantly stop
2. **Orders are squad-scoped** — no individual ship micromanagement exposed to player
3. **BattleState is the only state** — no global mutable game state
4. **Tags drive behavior** — no hardcoded per-ship combat logic
5. **Scenarios are JSON** — no hardcoded fleet layouts in code
