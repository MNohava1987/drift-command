# Drift Command — Game Balance Philosophy

**Purpose:** This document governs all balance decisions. Before changing any unit stat,
DPS value, cost, or mechanic, check it against the principles here.

---

## Core Principle: No Unit Wins All Phases

A unit that is dominant at all engagement distances, all fleet compositions, and all
budget levels is a design failure — not a success. Every unit must have:

1. A range or situation where it is strong
2. A range or situation where it is weak
3. An opponent unit that counters it even when deployed correctly

This is not "artificial nerfing." It is what makes fleet composition decisions meaningful.
If one unit type always wins, there are no decisions to make.

---

## The Counter Web

Balance is a **web**, not a triangle. Rock-paper-scissors creates a 3-way stalemate.
A web means every unit has multiple counters and multiple things it counters.

### Primary Counters (hard — the counter wins cleanly if deployed correctly)

| Unit | Loses to |
|---|---|
| Dreadnought | Torpedo runs (burst ignores PD, punishes low turn rate) |
| Battlecruiser | EW Cruiser + Torpedo (range nullified, then burst) |
| Strike Carrier | Interceptors (hunted before firing), EW (range neutered) |
| Heavy Cruiser | Strike Carrier at standoff, Torpedo runs |
| Destroyer | Gunboat swarms (overwhelmed, no area defense) |
| Gunboat Pack | Flak Frigates (area burst), Heavy Cruisers (PD + HP) |
| Interceptor | Direct fire at medium range (fragile, low HP) |
| Flak Frigate | Standoff missiles (outranged entirely) |
| EW Cruiser | Anything with weapons (no offense, must be escorted) |
| Repair Tender | Anything with weapons (no offense, must be escorted) |

### Secondary Counters (soft — the counter wins given good positioning)

| Unit | Disadvantaged against |
|---|---|
| Dreadnought | EW Cruiser (range cut from 280 to 182), Gunboat swarm |
| Strike Carrier | Direct fire ships that close range |
| Heavy Cruiser | EW forcing close engagement (loses range advantage) |
| Destroyer | Fast direct-fire ships (intercepted before torpedo range) |
| Gunboat | Any ship with weapon range >70 that can kite |

---

## Budget Economy

Budget is intentionally asymmetric. You cannot max-fill every role at any budget level.
Scenarios are designed around specific budget windows that force trade-off decisions.

### Budget windows per scenario target

| Budget | What It Enables | What It Forces You to Sacrifice |
|---|---|---|
| 6–8 | 1 capital + essentials OR 2 mid-tier + screen | Can't have both a capital and full escort |
| 10–12 | 1 capital + mid-tier mix + light screen | Can have depth but not everything |
| 14–16 | 1–2 capitals + full mid-tier | Can't afford Dreadnought + full support |
| 18+ | Nearly unconstrained at standard fleet | Dreadnought + Repair + EW possible but tight |

### Key tension the budget creates

- **Dreadnought vs depth:** Spending 7 on a Dreadnought means 3 less budget for escorts.
  A player who spends 7 on the Dreadnought but has no torpedo counter is one Destroyer squad
  away from losing their biggest asset.
- **Repair Tender dilemma:** 4 budget is expensive for a ship with no weapons.
  But in a sustained fight, a Repair Tender earns back its cost through extended HP.
  Short scenario = waste; long scenario = decisive.
- **EW Cruiser timing:** Costs 3 and has no weapons. In the right scenario
  (enemy heavy on carriers/dreadnoughts) it wins the battle. In the wrong scenario
  (enemy full swarm) it is dead weight.

---

## DPS Framework

All damage values are per-second at full effectiveness.

### Base DPS by weapon tag

| Tag | Base DPS | Notes |
|---|---|---|
| `directFire` | 8.0/s | Consistent. No modifiers except mode. |
| `missile` | 15.0/s | Interceptable. Effectively ~9/s with full PD coverage. |
| `torpedo` | ~24 burst | Not DPS — salvo fires 3× directFire in one hit, then 5s reload. Ignores PD. |
| `pointDefense` | 5.0/s | Against missiles only. Passive, no direct fire role. |
| `flak` | 8.0/s area | Applies to all ships within 60 units. Friend or foe. |
| `repair` | –6.0/s | Negative damage (healing). Applied to allies within 120 units. |

### Mode modifiers

| Condition | Damage Multiplier |
|---|---|
| Attacker in ATK mode | ×1.25 outgoing |
| Target in DEF mode | ×0.80 incoming |
| Flanking angle (>90° off heading) | ×1.35 bonus for `flanking` tag |
| Heavy broadside (perpendicular) | ×1.40 bonus for `heavyBroadside` tag |
| EW jamming field | Weapon range ×0.65 (not damage — range reduction only) |

### Effective DPS against a DEF-mode target with PD

| Attacker | Raw DPS | vs DEF target | vs DEF + PD target |
|---|---|---|---|
| Direct fire (ATK) | 10.0 | 8.0 | 8.0 (PD doesn't affect direct fire) |
| Missile (ATK) | 18.75 | 15.0 | 9.0 (PD intercepts 40%) |
| Torpedo (ATK) | ~30 burst | ~24 burst | ~24 burst (PD ignored) |

This is why torpedo is the hard counter to capitals: no defensive mode helps.

---

## HP Framework

HP values set the number of "time to kill" (TTK) seconds at base DPS.

| Ship | HP | TTK vs direct fire (8 DPS) | TTK vs missile (15 DPS) |
|---|---|---|---|
| Gunboat | 35 | 4.4s | 2.3s |
| Interceptor | 45 | 5.6s | 3.0s |
| Flak Frigate | 60 | 7.5s | 4.0s |
| Destroyer | 65 | 8.1s | 4.3s |
| Heavy Cruiser | 120 | 15.0s | 8.0s |
| Strike Carrier | 90 | 11.3s | 6.0s |
| EW Cruiser | 70 | 8.8s | 4.7s |
| Repair Tender | 55 | 6.9s | 3.7s |
| Flagship | 200 | 25.0s | 13.3s |
| Battlecruiser | 160 | 20.0s | 10.7s |
| Dreadnought | 300 | 37.5s | 20.0s |

**Design implication:** A Dreadnought at 300 HP takes 37 seconds to kill with direct fire.
That's the length of a full tempo cycle at the engaged band. A torpedo run (3× burst ~24 damage,
4 ships firing, 5s reload): 96 damage burst every 5 seconds = ~19 DPS effective.
300 HP / 19 DPS ≈ 16 seconds. Torpedo runs should kill Dreadnoughts — that's the design intent.

---

## Scale and Fleet Size

Current game loop: ~6–20 ships per side. Balance is tuned for this range.

### Minimum viable fleet

A fleet with only a Flagship (cost 0) should still function — slowly, with reduced
tactical options. The flagship has weapons and can survive some time.

### "Death spiral" prevention

When a fleet loses ships, it should not immediately lose all fights. The remaining
ships should be slower to kill than they were to deploy. Design choices that support this:
- Repair Tender heals surviving ships
- Heavy Cruiser and Dreadnought HP pools are large enough to survive a losing fight
- Squads with dead members elect a new leader — don't just stop functioning

### "Snowball" prevention

A fleet that is winning should not automatically win everything. Choices that prevent runaway:
- Torpedo runs are a cost-3 credible threat to any capital
- EW Cruiser only costs 3 and can neuter a 7-cost Dreadnought
- Gunboat swarms (cost 1) can overwhelm Destroyers and cause problems for slow capitals

---

## Scenario Balance Guidelines

Each scenario should have a "primary lesson" — one mechanic the player cannot win
without understanding. Balance the enemy fleet around teaching that mechanic,
not around maximum difficulty.

| Scenario | Budget | Enemy Archetype | Primary Lesson |
|---|---|---|---|
| 001 (First Contact) | 8 | Balanced line | Basic squad orders, ENGAGE vs DIRECT mode |
| 002 (Relay Hunt) | 8 | Swarm + flagship | Flak value, positioning escorts |
| 003 (Holding Action) | 8 | Heavy push | Sustain, Repair Tender timing |
| 004 (Ambush at the Gap) | 10 | Flanking | Counter-flanking, Destroyer vs Capital |
| 005 (Last Stand) | 12 | Full roster | Full balance, no single winning approach |

Enemy fleet compositions should not include units the player has no access to
in the available squad types for that scenario. If the enemy has a Dreadnought,
the player should have budget-accessible torpedo runs.

---

## What to Do When Something Feels Wrong

### "This unit is too strong"

1. Check if it has a deployed counter available to the player. If no counter exists in
   the scenario, the unit is not too strong — the scenario is missing its counter.
2. Check if the player is using the counter correctly. EW Cruisers need positioning.
   Torpedo runs need to actually reach torpedo range.
3. If a unit wins against everything including its designated counters,
   adjust the counter first (increase counter's effectiveness) before nerfing the unit.

### "This unit is useless"

1. Check if the scenario has conditions where it would shine.
   Repair Tenders are useless in short scenarios and decisive in long ones.
2. Check cost. A unit can be niche if it is cheap. A cost-1 unit doesn't need
   to win engagements — it needs to do one thing.
3. Check if a newer unit made it obsolete. If so, either remove the old unit
   or differentiate them more sharply.

### "The game is too easy / too hard"

Do not adjust base DPS or HP values globally. Adjust:
- Enemy budget allocation in scenarios
- Enemy AI posture (aggressive vs defensive vs flanking)
- Available squad types per scenario
- Scenario time limit (for survival missions)

---

## Change Log

| Date | Change | Rationale |
|---|---|---|
| 2026-03 | Initial balance framework | M7 prep: new ship roster |
