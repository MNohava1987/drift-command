# Drift Command — Game Design Pillars

## What This Game Is

A space fleet command simulation where **physics, distance, and imperfect information** are the core gameplay mechanics — not reflexes, not puzzle-solving. The player is the Admiral. The Admiral does not fly ships. The Admiral sets intent, issues orders, and watches consequences unfold — often too late to correct them.

The central tension: **you are always making decisions based on incomplete, delayed information, committing forces you cannot quickly recall, toward positions the enemy may have already left.**

---

## The Four Physics Pillars

These are non-negotiable. Every mechanic in the game must respect all four.

### 1. Momentum Is Real

Ships do not teleport to positions. They have a velocity vector and a mass. Thrust changes the vector gradually. A ship moving fast in one direction must burn energy and time to redirect. The heavier the ship, the longer this takes.

- A heavy capital ship at full burn takes significant time to reverse course
- A light raider can snap to a new heading quickly but carries less firepower
- All ships coast at their current velocity when not thrusting
- "Stopping" is not free — it requires thrust in the opposite direction

**Gameplay implication:** Speed is a commitment. Fast approach = you will overshoot. Orders issued late will be executed late, and by then the geometry has changed.

### 2. Speed Is a Tactical Choice

Every move order has an associated approach speed. Speed determines:
- **How quickly you arrive** at the target position
- **How much momentum you carry** through the engagement
- **How hard it is to redirect** after committing
- **How long the engagement window is** when two forces meet

Slow approach: controllable, adjustable, but exposes ships to fire longer.
Fast approach: brief engagement window, hard to redirect, may overshoot entirely.

A fast raider dispatched on a flanking arc at full speed will arrive quickly — but if the enemy has moved, that raider is now out of position and burning time to realign.

### 3. You See the Past, Not the Present

All sensor information is delayed by the distance light travels from the target to the observer. Nearby ships are nearly real-time. Distant ships are shown where they **were**, not where they **are**.

- The display shows each enemy ship's last known position with a timestamp
- The computer projects a **probability cone** showing where the ship likely is now, based on its last known velocity and heading
- If the enemy changes course, the player does not know until the new information arrives
- The Admiral's own ships report their status with the same delay

**Gameplay implication:** You are always commanding into uncertainty. The further away, the more stale your picture. Moving your command ship closer improves your information — but increases your risk.

### 4. The Admiral's Attention Is Finite

The Admiral sees the battlefield through a display — not omnisciently. Multiple things happen simultaneously. Focusing on one sector means not watching another.

This is a **view system mechanic**, not just a UI choice:
- The strategic view shows the full battlefield at scale
- Tactical views zoom into specific engagements with more detail
- Switching views takes attention — events happen while you're looking elsewhere
- Commanders (AI or human) manage their sectors while the Admiral manages the whole

---

## Ship Design Philosophy

Ships are defined by physical properties first, tactical role second. The physics engine derives behavior from stats — not from hard-coded role behaviors.

### Core Ship Properties

| Property | Effect |
|---|---|
| Mass | Determines how slowly thrust changes velocity. Heavy = hard to redirect. |
| Max thrust | Peak acceleration. Combined with mass = maneuverability. |
| Max speed | Terminal velocity under sustained thrust. |
| Turn rate | How quickly heading changes independent of velocity vector. |
| Sensor range | How far out the ship sees with low delay. |
| Weapon range | Engagement distance. |
| Weapon power | Damage output. |
| Durability | How much damage the ship absorbs. |
| Command capacity | How many units this ship can coordinate orders for (flagship / relay only). |

### Ship Classes (MVP)

- **Flagship (Capital):** Highest command capacity, heaviest armor, slowest to maneuver. Loss = defeat.
- **Command Relay:** Medium mass, extends command reach. Loss = subordinate ships go autonomous.
- **Heavy Line:** High durability and firepower, slow. The hammer.
- **Light Escort:** Medium speed, screening role. Protects capital ships.
- **Strike Carrier:** Medium mass, long weapon range. Stand-off fire platform.
- **Fast Raider:** Lowest mass, highest speed. Flanking and harassment. Fragile.

---

## Perspective System (View Layers)

The Admiral is not omniscient. The view system makes this mechanical.

### Strategic View (default)
Full battlefield at scale. All ships shown at their **sensor-delayed positions**. Trajectory projections visible. Command chain overlay optional. This is where the Admiral plans.

### Tactical View
Zoomed in on a specific engagement or sector. Higher detail — weapon range arcs, individual ship headings, damage readouts. The rest of the battlefield is not visible while zoomed in. Events happen off-screen.

### Commander View (future)
See exactly what a specific Commander sees — their sensor picture, their orders received, what they've issued to their ships. Used for understanding what a subordinate is doing and why.

### Bridge View (future / optional)
First-person Admiral's bridge. Multiple feed panels switchable. Highest immersion. Intended for multiplayer where the Admiral is a role, not the only player.

---

## Command Hierarchy (Current and Future)

```
Admiral (player)
  └── Commander A (AI or human player)
        └── Ship 1, Ship 2, Ship 3
  └── Commander B (AI or human player)
        └── Ship 4, Ship 5
```

### Current MVP implementation
Admiral issues orders directly to ships. Command Relay ships extend reach and reduce propagation delay. Loss of relay = ships go autonomous per doctrine.

### Future: Commander Layer
Commanders sit between Admiral and ships. They receive intent, interpret it through their personality and doctrine, and issue their own sub-orders. Commanders can:
- Misinterpret (plausibly)
- Over or under-commit based on risk tolerance
- Make local decisions the Admiral cannot see in time to override

The Admiral can tune how much autonomy each Commander has. High autonomy = less micromanagement, more unpredictability. Low autonomy = tighter control, higher cognitive load on the Admiral.

### Swappable Decision Providers
Every Commander role is a **Decision Provider** — a swappable interface. The current implementation uses a deterministic ruleset. Future implementations can swap in:
- More sophisticated rule-based AI
- Weighted utility AI with doctrine knobs
- Human player (multiplayer)
- Optional: external AI agent behind a bounded interface

---

## MVP Definition

MVP is the minimum that makes the **physics feel real** and the **Admiral role feel distinct from micromanagement**.

### MVP Must-Haves

- [ ] True momentum physics — ships coast, thrust changes vector gradually
- [ ] Speed setting per order — slow / medium / fast approach
- [ ] Trajectory projection — where will this ship be in N seconds?
- [ ] Sensor delay — enemies shown at delayed position, projected cone visible
- [ ] Strategic view with zoom — full battlefield default, tactical zoom available
- [ ] Tutorial — explains the four pillars before the first scenario
- [ ] 1-2 tight scenarios designed around the physics (not just "kill the enemy")

### Post-MVP (documented, not built yet)

- Commander interpretation layer (doctrine knobs, compliance variance)
- Commander view
- Bridge view / multi-panel display
- Formation orders (group selection + formation shapes)
- Multiplayer Commander slots
- Adaptive Commander behavior (history-based weight adjustment)
- Scenario editor
- Campaign layer (persistent consequences between battles)

---

## Tutorial Design

The tutorial must teach the four pillars, not the controls. Controls are secondary. The player must understand **why** things work the way they do before they are asked to use them.

Recommended flow:
1. **Momentum demo** — issue a fast move order, watch the ship overshoot. Show that redirecting costs time.
2. **Speed choice** — same order at slow speed. Show the tradeoff.
3. **Sensor delay** — show an enemy moving, show the delay between reality and display, show the projection cone.
4. **Command window** — explain pulse gating: why you can't issue orders continuously.
5. **First live scenario** — small, forgiving, outcome determined by whether the player understood the above.

The tutorial should be skippable after first completion.

---

## What the Game Should Feel Like

- Issuing a fast approach order and watching your ships commit to that vector — and then the enemy pivots and suddenly your flanking force is out of position with no way to correct in time.
- Sending a slow, careful advance and trading the speed for the ability to adjust as new sensor data arrives.
- Losing a Command Relay and watching three ships suddenly go autonomous — executing their doctrine, not your plan.
- Your Fast Raiders arriving at exactly where the enemy flagship *was* thirty seconds ago.
- Winning a battle you should have lost because you read the enemy's trajectory correctly and positioned your Heavy Line ships to intercept.

The game is won and lost in the planning phase, not the execution phase. Execution is physics. Planning is the game.
