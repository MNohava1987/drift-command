# Drift Command — Ship Roster & Design Rationale

**Status:** Approved design. Tiers 1–3 partially implemented. Full roster is the target state.
**Rule:** Do not add a ship to code until it appears in this document with a complete entry.

---

## Design Constraints

Every ship must satisfy all of the following before being added:

1. **It has a clear answer to "what does this beat?"** — at least two unit types it counters
2. **It has a clear answer to "what beats this?"** — at least one hard counter, one soft counter
3. **Its cost is proportional to the number of things it beats** — cheap units beat one thing well; expensive units beat many things adequately
4. **It cannot dominate all phases of engagement** — long-range specialists should be weak up close; fast units should be fragile
5. **It has a distinct visual silhouette** — players must be able to read it at a glance on mobile

---

## The Counter Web

```
SWARM (Gunboats)
   │ beats
   ▼
CAPITALS (slow, can't track)       FLAK FRIGATE beats SWARM
   │ beats                              │
   ▼                               beaten by
SCREENING (Escorts, outnumbered)         │
                                    LONG RANGE (Carrier, Dreadnought)
TORPEDO (Destroyer)                      │ beaten by
   │ beats                               │
   ▼                                DESTROYER (Torpedo)
CAPITALS (high HP target)                │ beaten by
   │ beaten by                           │
   ▼                                  SWARM (overwhelms destroyers)
SWARM (overwhelms destroyers)
```

**Support units (EW Cruiser, Repair Tender) sit outside the loop:**
- EW Cruiser amplifies any fleet by reducing enemy effective range
- Repair Tender extends any fight — makes sustained attrition favor whoever has one
- Both are high-priority targets, not direct fighters

**Flak types form a sub-web:**
- Interceptor: chases missile carriers, shoots down in-flight missiles (reactive)
- Flak Frigate: area burst punishes tight formations (static/area)
- Escort/Heavy Cruiser: passive PD reduces missile damage (always-on modifier)

---

## Cost Scale

Budget is the primary balance lever. A 12-budget fleet should feel meaningfully different
from a 6-budget fleet even if both have the same ship count.

| Cost | Expectation |
|---|---|
| 0 | Flagship only. Unique, always present. |
| 1 | Cheap, fragile, one clear purpose. Expendable. |
| 2 | Reliable for one role. Can die to bad positioning. |
| 3 | Solid generalist or strong specialist. |
| 4 | Fleet anchor. Demands support to survive. |
| 5–6 | Capital ship. Changes a battle. Needs escort. |
| 7–8 | Game-ending threat if uncontested. Requires multiple counters. |

---

## Ship Roster

### Tier 0 — Command

#### Flagship
| Property | Value |
|---|---|
| Hull | `flagship` |
| Role | `ShipRole.flagship` |
| Cost | 0 (always present) |
| HP | 200 |
| Weapon range | 120 |
| Mass | Capital |
| Tags | `directFire` |
| Label | F |

**Design:** Loss = defeat. The flagship is not a combat ship — it happens to have weapons.
Its job is to exist. Players should feel instinctive protection of it.
**Beats:** Nothing specifically. Its value is existence, not combat.
**Beaten by:** Everything. Protect it.

---

### Tier 1 — Flak / Screen (cost 1–2)

These are bought in quantity. Die easily. Shape the battle.

#### Gunboat
| Property | Value |
|---|---|
| Hull | `gunboat` |
| Role | `ShipRole.gunboat` |
| Cost | 1 |
| HP | 35 |
| Weapon range | 70 |
| Mass | Light |
| Accel | 38.0 |
| Turn rate | 2.2 |
| Tags | `directFire`, `flanking` |
| Label | G |
| Squad | `gunboatPack` (8× ships, cost 1) |

**Design:** The swarm unit. Eight of them cost 1 budget point.
Individually meaningless; collectively overwhelming against anything that moves slowly.
The flanking tag gives them +35% damage when attacking from a target's rear arc.
**Beats:** Slow capitals (can't track), anything that doesn't have area weapons.
**Beaten by:** Flak Frigates (area burst), Interceptors, any ship with PD when they cluster.

#### Interceptor
| Property | Value |
|---|---|
| Hull | `interceptor` |
| Role | `ShipRole.interceptor` |
| Cost | 1 |
| HP | 45 |
| Weapon range | 110 |
| Mass | Light |
| Accel | 32.0 |
| Turn rate | 2.0 |
| Tags | `directFire`, `intercept`, `pointDefense` |
| Label | I |
| Squad | `interceptorScreen` (6× ships, cost 1) |

**Design:** Replaces the old Light Escort concept. Active hunter rather than passive screen.
The `intercept` tag means this ship preferentially targets missile carriers
and moves to intercept incoming missiles before they reach allies.
**Beats:** Strike Carriers, incoming missiles (reduces missile DPS to nearby allies).
**Beaten by:** Direct fire at medium range, anything with more HP.

#### Flak Frigate
| Property | Value |
|---|---|
| Hull | `flak_frigate` |
| Role | `ShipRole.flakFrigate` |
| Cost | 2 |
| HP | 60 |
| Weapon range | 80 |
| Mass | Light |
| Accel | 20.0 |
| Turn rate | 1.2 |
| Tags | `flak` |
| Label | K |
| Squad | `flakLine` (3× ships, cost 2) |

**Design:** Area burst weapon. Every tick, damages ALL ships (friend or foe) within
a 60-unit radius. Punishes enemy formations clustering together.
Forces enemies to spread out — which in turn makes them easier to pick off individually.
The friendly-fire risk means placement matters. Do not cluster your own ships behind it.
**Beats:** Gunboat swarms, anything that needs to close range.
**Beaten by:** Long-range missiles (outranged), anything that stays outside 80 units.

---

### Tier 2 — Line / Middle (cost 3–4)

Workhorses. Most of the fleet budget goes here.

#### Destroyer
| Property | Value |
|---|---|
| Hull | `destroyer` |
| Role | `ShipRole.destroyer` |
| Cost | 3 |
| HP | 65 |
| Weapon range | 80 |
| Mass | Light |
| Accel | 28.0 |
| Turn rate | 1.8 |
| Tags | `torpedo`, `directFire` |
| Label | D |
| Squad | `torpedoRun` (4× ships, cost 3) |

**Design:** Predator of capital ships. Torpedo salvo: fires a burst (3× concentrated damage)
then reloads for 5 seconds. Ignores point defense — torpedoes are too fast/dense to intercept.
Closes to short range, fires everything, breaks off. Terrifying to a Dreadnought.
**Beats:** Heavy Cruisers, Battlecruisers, Dreadnoughts (torpedo ignores PD, punches through HP).
**Beaten by:** Gunboat swarms (overwhelmed, no PD), Flak Frigates at close range.

#### Heavy Cruiser
| Property | Value |
|---|---|
| Hull | `heavy_cruiser` |
| Role | `ShipRole.heavyCruiser` |
| Cost | 3 |
| HP | 120 |
| Weapon range | 150 |
| Mass | Heavy |
| Accel | 8.0 |
| Turn rate | 0.2 |
| Tags | `directFire`, `pointDefense` |
| Label | H |
| Squad | `cruiserDivision` (2× ships, cost 3) |

**Design:** The reliable center. Solid HP, good range, passive PD reduces missile damage to
nearby allies. Slow — needs positioning. The anchor of a line engagement.
**Beats:** Destroyers in a straight fight (HP advantage, longer range), Gunboats (PD + HP).
**Beaten by:** Strike Carriers at standoff range (outranged), Torpedo runs, EW forcing close engagement.

#### EW Cruiser
| Property | Value |
|---|---|
| Hull | `ew_cruiser` |
| Role | `ShipRole.ewCruiser` |
| Cost | 3 |
| HP | 70 |
| Weapon range | — (no weapons) |
| Mass | Medium |
| Accel | 15.0 |
| Turn rate | 0.8 |
| Tags | `jamming` |
| Label | W |
| Squad | `ewFlight` (2× ships, cost 3) |

**Design:** Emits a jamming field in a 150-unit radius. Any enemy ship inside the field
has its effective weapon range cut by 35%. Forces long-range ships to close — losing their
standoff advantage. A Dreadnought with 280-unit range becomes a 182-unit threat inside a jam field.
No weapons — this ship needs an escort. High priority target for the enemy AI.
**Beats:** Long-range platforms (Carriers, Dreadnoughts) — neuters their range.
**Beaten by:** Everything with weapons. Requires protection. Useless against short-range swarms.

#### Strike Carrier
| Property | Value |
|---|---|
| Hull | `strike_carrier` |
| Role | `ShipRole.strikeCarrier` |
| Cost | 4 |
| HP | 90 |
| Weapon range | 200 |
| Mass | Medium |
| Accel | 15.0 |
| Turn rate | 0.6 |
| Tags | `missile` |
| Label | C |
| Squad | `carrierGroup` (2× ships, cost 4) |

**Design:** Existing ship, kept. Missile platform at longest range in the mid-tier.
Missiles can be intercepted by PD ships and Interceptors. Vulnerable if enemy closes range
or has Interceptors deployed. The threat of Interceptors is meant to create an
"I need to answer that carrier group" feeling.
**Beats:** Heavy Cruisers at standoff (outranges their PD), Dreadnoughts at standoff.
**Beaten by:** Interceptors (hunted down), EW Cruisers (range cut kills effectiveness), any ship that closes to melee.

#### Repair Tender
| Property | Value |
|---|---|
| Hull | `repair_tender` |
| Role | `ShipRole.repairTender` |
| Cost | 4 |
| HP | 55 |
| Weapon range | — (no weapons) |
| Mass | Medium |
| Accel | 12.0 |
| Turn rate | 0.5 |
| Tags | `repair` |
| Label | R |
| Squad | `supportGroup` (2× ships, cost 4) |

**Design:** Heals nearby allied ships at 6 HP/s within 120 units. No weapons.
Changes the nature of an attrition fight — whoever has a Repair Tender sustains longer.
Enemy AI should prioritize killing this ship. Needs heavy escort.
A Repair Tender behind a Heavy Cruiser wall is a significant force multiplier.
**Beats:** (Amplifies allies — not a direct counter unit)
**Beaten by:** Everything. Requires protection. The enemy should always want to kill it first.

---

### Tier 3 — Capitals (cost 5–8)

Rare. One or two per fleet. Fleet-defining. Clear weaknesses.

#### Battlecruiser
| Property | Value |
|---|---|
| Hull | `battlecruiser` |
| Role | `ShipRole.battlecruiser` |
| Cost | 5 |
| HP | 160 |
| Weapon range | 180 |
| Mass | Heavy |
| Accel | 18.0 |
| Turn rate | 0.5 |
| Tags | `directFire`, `missile`, `pointDefense` |
| Label | B |
| Squad | `battlecruiserGroup` (1× ship, cost 5) |

**Design:** The "almost a dreadnought" choice. Fast capital — can pursue, can reposition.
Has both direct fire and missiles, plus passive PD. Costs 2 less than a Dreadnought.
The question a player faces: "Do I want mobility (Battlecruiser) or raw power (Dreadnought)?"
**Beats:** Most mid-tier ships in a direct engagement. Fast enough to chase raiders.
**Beaten by:** Torpedo runs (high HP but not overwhelming), EW cutting missile range,
coordinated swarm (flanking from multiple angles taxes its turning).

#### Dreadnought
| Property | Value |
|---|---|
| Hull | `dreadnought` |
| Role | `ShipRole.dreadnought` |
| Cost | 7 |
| HP | 300 |
| Weapon range | 280 |
| Mass | Capital |
| Accel | 6.0 |
| Turn rate | 0.1 |
| Tags | `directFire`, `heavyBroadside`, `pointDefense` |
| Label | N |
| Squad | `dreadnoughtGroup` (1× ship, cost 7) |

**Design:** The apex unit. Highest HP, longest weapon range, heaviest broadside.
The `heavyBroadside` tag gives it a damage bonus when firing perpendicular to its target
— rewards the player who maneuvers their Dreadnought sideways into a broadside position.
Its weakness is baked in: extremely slow turn rate (0.1 rad/s) means Destroyers that
get inside its engagement envelope are nearly impossible to track.
Torpedo runs are the intended hard counter — 4 Destroyers (cost 3 budget) should be
a credible threat to a 7-cost Dreadnought if they get close.
**Beats:** Everything at standoff range. No unit can outgun it at distance.
**Beaten by:** Torpedo runs (burst damage, ignores PD), EW Cruisers (cuts 280 range to 182),
gunboat swarm inside its minimum tracking angle.

---

## Existing Ships — Migration Path

| Old Hull | Status | New Hull | Notes |
|---|---|---|---|
| `flagship` | Keep as-is | `flagship` | No change |
| `heavy_line` | Rename | `heavy_cruiser` | Add `pointDefense` tag. Update squad references. |
| `light_escort` | Replace | `interceptor` | Replace `screening` with `intercept` tag. |
| `strike_carrier` | Keep as-is | `strike_carrier` | No change |
| `fast_raider` | Replace | `gunboat` | Same archetype. Adjust stats slightly. |

**Note:** Renaming hulls requires updating scenario JSON files and any SharedPrefs keys
that store durability fractions by hull ID. Update `kShipDefinitions` key, not just
the `displayName`.

---

## Squad Roster (Complete)

| Squad Type | Ships | Cost | Primary Role |
|---|---|---|---|
| `flagship` | 1× flagship | 0 | Command anchor |
| `gunboatPack` | 8× gunboat | 1 | Swarm pressure |
| `interceptorScreen` | 6× interceptor | 1 | Anti-missile / carrier hunter |
| `flakLine` | 3× flak_frigate | 2 | Anti-swarm area denial |
| `torpedoRun` | 4× destroyer | 3 | Capital ship predator |
| `cruiserDivision` | 2× heavy_cruiser | 3 | Line anchor |
| `ewFlight` | 2× ew_cruiser | 3 | Range suppression |
| `carrierGroup` | 2× strike_carrier | 4 | Standoff fire |
| `supportGroup` | 2× repair_tender | 4 | Fleet sustain |
| `battlecruiserGroup` | 1× battlecruiser | 5 | Mobile capital |
| `dreadnoughtGroup` | 1× dreadnought | 7 | Apex firepower |

---

## Tags Reference

| Tag | Mechanic |
|---|---|
| `directFire` | Auto-fires at nearest enemy in weapon range. Base DPS 8/s. |
| `missile` | Fires missiles at 15 DPS. Interceptable by `pointDefense`/`intercept` ships. |
| `torpedo` | Salvo burst (3× normal damage hit) then 5s reload. Ignores all PD/intercept. |
| `pointDefense` | Passive: reduces missile DPS against nearby allies by 40%. |
| `intercept` | Active: preferentially targets missile carriers; moves to shoot down in-flight missiles. |
| `flak` | Area burst: damages ALL ships within 60 units when firing (friend or foe). |
| `flanking` | +35% damage when attacking from target's rear arc (>90° off target heading). |
| `jamming` | Aura: enemy weapon ranges cut 35% within 150-unit radius. |
| `repair` | Aura: heals allied ships 6 HP/s within 120-unit radius. |
| `heavyBroadside` | +40% damage when attacker is perpendicular to target (broadside firing arc). |
