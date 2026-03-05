# Relay and Mesh Communications

## Core Principle

Orders travel by the shortest available path, not through a fixed hierarchy.

If the flagship is closer to the heavy than the relay is, the order goes directly
to the heavy. The relay exists to extend effective command range — not to be a
mandatory bottleneck.

```
Flagship ──── Heavy (close)       → direct, faster
Flagship ──── Relay ──── Escort   → relay saves distance, faster via relay
```

This means:
- Ships that drift close to the flagship respond quickly regardless of topology
- Losing a relay hurts distant ships (they lose the range extender) but doesn't
  isolate ships that happen to be near the flagship
- Positioning matters: closing the distance between your flagship and a ship
  is itself a command latency tactic

## Current Implementation (M4+)

`CommandSystem._calculatePropagationDelay()` computes both paths and uses the
minimum. The transit pulse in the renderer takes the same path, so what the
player sees matches what the simulation actually did.

## Relay as Deployable Resource (Future — Not Yet Built)

The relay is currently a ship. The intended long-term design is different:

**Relays should be deployable**, launched from an escort or carried as a
consumable resource, not a dedicated ship with its own hull and crew.

### Vision

- Escort carries 1–2 relay buoys as a passive loadout
- Player uses a **DEPLOY** ability to drop a relay at the escort's current position
- Deployed relay is a small, fragile, stationary node — no engines, minimal HP
- It extends the command mesh at that location for the duration of the battle
- Enemy can destroy it — removes the node from the topology, stranding distant ships

### Why This Matters

A fixed relay ship creates a predictable target. A deployable relay creates
real-time decisions:
- Where do I place it? (Cover a flank? Extend range toward an objective?)
- When? (Early for reach, or save the escort for combat and relay later?)
- Do I protect the buoy or sacrifice it?

### Impact on Enemy Escort Doctrine

When relays are deployable, the enemy escort's AI goal becomes:
1. Intercept player escort before it can deploy
2. Hunt deployed relay buoys to collapse the player's command network

This makes the escort a real tactical asset, not just a small combat ship.

### Implementation Notes (When Ready)

- `ShipData` gains `relayCharges: int` (0 for most ships, 1–2 for escort)
- New `OrderType.deployRelay` triggers `ScenarioLoader`-style node creation at
  current position
- Deployed relay has no `dataId` ship hull — it's a `CommandNode` with
  `durability` tracked separately
- Renderer draws deployed relays as small diamond markers, not circles
- `CommandSystem` topology update needed when relays are added/removed mid-battle

---

## Visual Differentiation (Planned for M5)

Currently all chain lines are the same style.
Planned:
- **Flagship → relay**: solid white 15% — command backbone
- **Relay → ships**: solid white 10%
- **Direct flagship → ship (relay skipped)**: dashed white 8% — indicates
  the ship is close enough to bypass the relay
- **Isolated ship**: red dotted line to last known relay position — visually
  indicates command breakdown
