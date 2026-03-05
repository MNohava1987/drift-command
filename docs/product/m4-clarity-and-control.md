# M4 — Clarity and Control

## Problem Statement

The game is mechanically sound but visually illegible and control-sticky.
Players cannot tell ship types apart, cannot cancel orders once issued,
cannot pause to plan, and cannot see the command chain working.
The result is a battle that feels chaotic rather than strategic.

M4 fixes legibility and control before adding any new mechanics.

---

## Features

### 1. Pause / Play

A pause button (or spacebar on desktop) freezes the simulation.
While paused:
- All ships hold their current position and velocity
- The player can issue orders, select ships, review the battlefield
- Trajectory projections and sensor ghosts still render
- Order lines update to reflect new orders issued during pause
- The battle clock stops

Resuming unpauses everything simultaneously.

**Why it matters:** The game is about planning under uncertainty.
Pause is what lets planning happen. Without it, the game is reflexes.

---

### 2. Cancel Orders

A **CANCEL** button in the action bar clears all pending and active
orders for the selected ship. The ship coasts on its current velocity
until a new order arrives.

This is distinct from HOLD:
- CANCEL: wipe the order queue, ship coasts freely
- HOLD: issue an explicit stop order (brakes to zero, stays put)

Tap behavior: tapping an already-selected ship re-selects it
(no accidental deselect). The CANCEL button is the explicit clear.

---

### 3. Ship Type Labels

Each ship dot displays a single-character type label:

| Ship type | Label |
|---|---|
| Flagship | F |
| Command Relay | R |
| Heavy Line | H |
| Light Escort | E |
| Strike Carrier | C |
| Fast Raider | X |

Player ships: label in white. Enemy ships: label in the enemy color.
Label renders at the center of the dot, sized to fit.

---

### 4. Command Chain Lines

Persistent faint lines connecting the command hierarchy:

```
[Flagship] ──── [Relay] ──── [Heavy]
                        ──── [Escort]
```

- Flagship → Relay: solid dim line
- Relay → assigned combat ships: solid dimmer line
- Player faction only (enemy chain not shown)
- Color: white at 15% opacity — visible but not distracting
- If a relay is destroyed, its lines disappear (ships show as isolated)

This makes the command structure spatially visible at all times.
The player can see at a glance which ships are connected to what.

---

### 5. Order-in-Transit Pulse

When an order is issued, a small dot travels from the flagship
along the command chain toward the target ship.

- Flagship → Relay leg: pulse travels at `kBasePropagationSpeed`
- Relay → target leg: pulse continues at the same speed
- The dot disappears when the order arrives (ship's pending order becomes active)
- Color: yellow (matches pending order lines)
- Size: 3px dot

This makes the propagation delay *visible* and physical.
The player watches their order travel and knows when it will land.

---

## What This Is Not

- Not a new game mechanic
- Not a scenario change
- Not a physics change

M4 is entirely UI and rendering. No changes to core systems.

---

## Post-M4 (Next Design Questions)

These are identified but not scoped for M4:

**Approach types:** "Match velocity and engage" vs "charge" are
distinct tactical choices that warrant distinct order types —
not just speed settings. Design needed before building.

**Curved waypoints:** Multi-point paths with a drag UI.
Significant UX design required first.

**Weapon behavior per ship type:** Scatter vs precision,
range vs damage tradeoffs. Requires combat system rework.

**Admiral ≠ flagship captain:** The Admiral issues strategic orders;
a Commander runs the flagship tactically. This is the Phase 2
commander layer — scoped separately in command-chain-vision.md.
