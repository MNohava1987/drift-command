# Command Chain + Interpreted Orders — Post-MVP Vision

## Core Fantasy

The player is the **Admiral**, operating at strategic scale — solar-system distances, long commitment windows, delayed consequences. Orders flow down a command chain and are **interpreted**, not executed perfectly. Mistakes, personality, and imperfect information are features, not bugs.

```
Admiral (player)
    └── Commander A (AI or human)
            └── Ship 1, Ship 2, Ship 3
    └── Commander B (AI or human)
            └── Ship 4, Ship 5
```

Commanders don't just relay orders. They interpret intent through the lens of their doctrine, personality, and local situation. A cautious Commander receiving "advance" may hold until the odds improve. An aggressive one may overcommit.

---

## Architecture Principle: Decision Providers

Every decision-making role (Commander, Ship) is a **Decision Provider** — a swappable interface:

```
Inputs:
  - Situation snapshot (sensor data, threat assessment)
  - Received order (from Admiral or superior Commander)
  - Doctrine / personality parameters
  - Historical context (what worked, what failed)

Output:
  - Chosen actions / sub-orders issued to subordinates
```

The MVP agent is a simple deterministic ruleset. The interface stays the same when you swap it for a weighted utility system, an adaptive rule engine, or an LLM-backed agent. **The command pipeline never needs to change.**

---

## Phase Roadmap

### Phase 1 — MVP (complete)
Deterministic command execution.

- Admiral issues orders directly to ships
- Orders propagate with time delay (distance / comm speed)
- Ships follow orders literally — simple rules, no personality
- Validates the core "commitment / can't pivot instantly" gameplay loop

### Phase 2 — Commander Interpretation Layer
First real AI-like behavior. Commanders sit between Admiral and ships.

Knobs per Commander:
- **Doctrine**: aggressive / cautious / opportunistic
- **Compliance**: literal vs flexible interpretation of orders
- **Risk tolerance**: commit vs abort thresholds

Misinterpretation is intentional and part of gameplay:
- "Advance on the relay" → cautious Commander holds at range and fires instead
- "Screen the flagship" → aggressive Commander interprets as "attack anything that approaches"

Commanders have **perspective constraints** — they only see what their sensors see. The Admiral's view is broader but slower to act on.

### Phase 3 — Adaptive Behavior
Commanders accumulate a lightweight history record.

- What orders were given
- What actions were taken
- What succeeded or failed

Behavior shifts over a campaign:
- **Confidence adjustment**: a Commander who succeeded gains autonomy; one who failed defers more
- **Preference shifts**: avoids tactics that previously failed in similar situations
- Implemented as rule weight adjustments — not ML, no training required

### Phase 4 — Optional LLM Agent Container
A plug-in layer, not a dependency. The game runs fully offline and deterministically without it.

Prompt shape:
```
You are Commander X.
Doctrine: cautious, screening role.
Situation: [sensor snapshot]
Received order: "Hold the left flank."
History: [last 3 engagements summary]
Decide: what orders do you issue to your ships?
```

The container sits behind the Decision Provider interface. Uncontrolled output is bounded by the interface contract — the game only accepts valid action types, not free-form behavior.

### Phase 5 — Multiplayer Role Replacement
Humans can fill Commander slots, replacing the AI decision-maker for that role.

- A friend joins as Commander A — they see the Commander's information picture, not the Admiral's
- They issue orders to their assigned ships within the same delay/doctrine constraints
- The Admiral still commands overall; Commanders execute with their own judgment
- Supports **co-op staff gameplay**: Admiral + one or more human Commanders

---

## What Not to Build Too Early

- Don't add Commander interpretation before the core commitment loop is fun (Phase 1 must feel good first)
- Don't make LLM agents load-bearing — always keep the deterministic fallback
- Don't give Commanders perfect information — their limited perspective is the point
- Don't over-tune compliance to 100% — predictable Commanders remove the tension

---

## Relationship to Current Architecture

The current codebase already partially supports this:

| Existing | Maps to |
|---|---|
| `DoctrineAI` | Phase 2 Commander layer (expand in place) |
| `CommandSystem.issueOrder()` | The order-passing pipeline between levels |
| `Doctrine` enum (hold/engage/retreat/screen) | Phase 2 doctrine knobs (expand) |
| `Order.arrivesAt` propagation delay | Already handles comm latency at all levels |
| `assignedCommandNodeId` on ships | The chain-of-command mapping already exists |

Phase 2 adds a Commander decision step between `DoctrineAI` and `CommandSystem` — no pipeline rewrite needed.
