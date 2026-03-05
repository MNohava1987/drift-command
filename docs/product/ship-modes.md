# Ship Modes and Capabilities

## Design Philosophy

Ships do not have one-shot ability buttons. They have **modes** — persistent
states that change how the ship behaves until toggled off.

Issuing an attack order while a ship is in Defensive Mode does not cancel the
mode. Modes and orders are orthogonal: orders say *where to go and what to target*,
modes say *how to behave while doing it*.

This mirrors reality: a warship doesn't "use" point defense once — it either has
its defensive systems running or it doesn't.

## Mode Toggle UX

- Mode buttons appear in the action bar when a ship is selected
- Active mode is highlighted (lit border, colored background)
- Modes persist across orders — they stay on until the player turns them off
- Some modes have costs: reduced speed, increased sensor signature, power draw
  (abstract for now, can become fuel/power system later)
- Modes do NOT consume a command pulse — they are ship-level configuration

## Ship Mode Definitions

### Escort (Light Escort)

| Mode | Effect | Trade-off |
|---|---|---|
| **Attack** (default) | Closes to weapon range, fires on target | Exposed, low HP |
| **Defensive Screen** | Intercept incoming missiles at 40% rate (existing point defense). Orbits nearest friendly capital within 80 units. | Does not close on enemies. Effective only when near an ally |
| *(future)* **Sprint** | +30% max speed | No weapons active while sprinting |

Defensive Screen is the mode that makes point defense feel intentional.
Currently point defense fires passively at all times — toggling it means the
player chooses when to commit the escort to a screening role vs. an attack role.

### Heavy Line Ship

| Mode | Effect | Trade-off |
|---|---|---|
| **Advance** (default) | Moves to ordered position, fires at enemies in range | Slow to stop |
| **Volley** | Focused fire burst: double DPS for 3 s, then 12 s cooldown | Visual: weapon glow. Overheats. |
| *(future)* **Suppression** | Area denial: lower DPS but forces nearby enemies to reduce speed | Needs range-based effect system |

### Strike Carrier

| Mode | Effect | Trade-off |
|---|---|---|
| **Strike** (default) | Fires missiles at target. 200-unit range. | Missile can be intercepted |
| **Standoff** | Retreats to max missile range from nearest enemy automatically | Gives up position control |
| *(future)* **Launch Strike** | Deploys strike craft wave (requires strike craft system) | |

### Fast Raider

| Mode | Effect | Trade-off |
|---|---|---|
| **Flank** (default) | Attacks target from 90° off approach vector | Requires maneuvering room |
| **Harass** | Fires and retreats in a loop — never closes past 60% weapon range | Lower damage output |
| *(future)* **Electronic Warfare** | Disrupts a relay node — adds 3 s to all orders routed through it | Needs EW system |

### Flagship

| Mode | Effect | Trade-off |
|---|---|---|
| **Command** (default) | Normal behavior. Flagship stays back. | |
| **Vanguard** | Flagship advances with fleet, reducing latency for all ships | Flagship at risk |
| *(future)* **Emergency Broadcast** | All ships receive orders simultaneously for 5 s, ignoring relay topology | One-time, costly |

### Command Relay (ship form, pre-deployable-relay design)

| Mode | Effect | Trade-off |
|---|---|---|
| **Midfield** (default) | AI holds midfield position | |
| **Advance** | Relay moves toward enemy — reduces latency for ships on that flank | Relay closer to enemy weapons |

---

## Implementation Plan (M5)

1. Add `activeMode: ShipMode?` to `ShipState`
2. Add `availableModes: List<ShipMode>` to `ShipData`
3. Mode buttons appear in action bar as small icons with active indicator
4. `CombatSystem` and `KinematicSystem` check `ship.activeMode` when deciding
   behavior — mode modifiers applied as multipliers or alternate code paths
5. Mode changes do NOT go through the command pulse — they take effect immediately
   (the ship's crew decides how to operate; the admiral just sets the posture)

---

## What This Is Not

- Not a skill tree or RPG progression — all modes available from battle start
- Not an ability cooldown system (that's Volley above, which is an exception)
- Not a replacement for orders — modes set posture, orders set destination/target
- Not a complexity dump — each ship has 2 modes max in M5 (default + one toggle)

The goal is one meaningful choice per ship type, not a menu of options.

---

## Ship Codex (Future UI Feature)

A readable description of each ship available before battle starts (or accessible
during pause). Each entry covers:

- Role in plain language ("The escort is your fastest ship and your missile shield")
- Strengths and weaknesses in bullet points
- Available modes with brief descriptions
- Example tactics ("Use the raider to loop around and target the enemy relay")

This replaces tutorial text with in-game reference material the player
can consult when confused.
