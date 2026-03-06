# Code Review — Post M6 Squad System

**Date:** 2026-03
**Scope:** Full game-client lib/ audit — security, cleanliness, efficiency, config separation
**Result:** No critical issues. 3 moderate efficiency concerns, 8 config separation gaps.

---

## Security

**Score: Clean. No issues found.**

- No hardcoded secrets or credentials
- SharedPreferences used safely (non-sensitive data only: scenario completion flags, durability fractions)
- JSON parsing uses proper type casting and null checking
- Asset loading via `rootBundle.loadString` is standard practice
- No `eval`, dynamic code execution, or external network calls in game logic

---

## Cleanliness

### MODERATE — Tutorial references removed mechanics

**File:** `lib/ui/screens/tutorial_screen.dart` (lines 61–94)

The tutorial mentions command windows and pulse gating that were removed in M2/M3.
Players who read the tutorial are taught mechanics that no longer exist.

**Fix:** Update tutorial text to reflect current mechanics: squad system, engagement
modes (DIRECT/ENGAGE/GHOST), deployment screen, and the four design pillars.

---

### MINOR — Dead parameter in ScenarioLoader

**File:** `lib/core/services/scenario_loader.dart` (lines 13–14)

`carryDamage` and `startingDurabilityFractions` are accepted for backwards compatibility
but not applied. The comment acknowledges this. Formalize with a `@Deprecated` annotation
or remove in the next major cleanup.

---

### MINOR — Audio load failure silently swallowed

**File:** `lib/game/battle_game.dart` (lines 113–121)

```dart
try {
  await FlameAudio.audioCache.loadAll([...]);
  _audioReady = true;
} catch (_) {}
```

Acceptable for graceful degradation, but silent failure makes debugging hard.
Consider logging in debug mode: `assert(() { debugPrint('Audio load failed: $e'); return true; }());`

---

### MINOR — Sound file names are magic strings

**File:** `lib/game/battle_game.dart` (lines 114–118, 142, 183, 263, 276, 291)

`'weapon_fire.ogg'`, `'order_click.ogg'`, etc. appear multiple times.
See config-architecture.md for migration to named constants.

---

## Efficiency

### MODERATE — O(n²) distance loop in TempoSystem (hot path)

**File:** `lib/core/systems/tempo_system.dart` (lines 23–28)

```dart
for (final p in playerShips) {
  for (final e in enemyShips) {
    final d = p.position.distanceTo(e.position);
    if (d < minDistance) minDistance = d;
  }
}
```

Called every frame. At 20 ships/side = 400 distance calculations/frame. Fine now.
At 100 ships/side = 10,000 calculations/frame. Will become noticeable.

**Fix when:** Fleet sizes exceed 40 ships/side. Mitigation: sample a subset of ships
(e.g., only squad leaders) rather than all ships. Reduces from O(n²) to O(squads²).

---

### MODERATE — O(n²) combat target selection (hot path)

**File:** `lib/core/systems/combat_system.dart` (lines 74–96)

For each attacker, `_selectTarget()` scans all alive enemies. N attackers × M enemies
each frame. At 20v20 = 400 iterations. At 100v100 = 10,000.

**Fix when:** Same threshold as above. Mitigation: pre-compute alive enemy list once
per frame outside the attacker loop. Already costs one allocation but cuts repeated
`state.ships.values` iteration.

---

### MODERATE — Point defense check iterates all ships per-target (hot path)

**File:** `lib/core/systems/combat_system.dart` (lines 150–159)

`_hasNearbyPointDefense()` iterates all ships to find friendly PD ships near the target.
Called once per missile-capable attacker per frame.

**Fix when:** Multiple carriers firing simultaneously. Pre-compute a `defensivePdShips` list
once per frame, filtered to alive + defensive mode + has PD tag. Reduces repeated work.

---

### MINOR — New list allocation on every combat frame

**File:** `lib/core/systems/combat_system.dart` (line 32)

`_state.ships.values.where((s) => s.isAlive).toList()` creates a new list each frame.
Not a problem now (small fleets, GC handles it), but worth caching.

---

### MINOR — Dashed line drawing not cached

**File:** `lib/game/components/battlefield_renderer.dart` (lines 601–634)

The dashed line helper computes new vertex positions every frame. Acceptable for
the current number of dashed lines (sensor ghosts + trajectories). Would be expensive
with many simultaneous trajectory/ghost lines.

---

## Config / Code Separation

See `docs/technical/config-architecture.md` for the full migration plan.

### MODERATE — World dimensions defined twice

**Files:**
- `lib/game/components/battlefield_renderer.dart` lines 35–36
- `lib/ui/screens/deployment_screen.dart` lines 36–37

Both define `kWorldWidth = 2000.0` and `kWorldHeight = 1200.0` independently.
If one changes, the other doesn't. This will cause visual mismatches.

**Fix:** Single definition in `lib/data/game_config.dart`, imported by both.

---

### MODERATE — Combat balance constants scattered across 6+ locations

Key combat modifier values that should be in one place:

| Value | Current location |
|---|---|
| DPS by tag (`kWeaponDps`) | `combat_system.dart:6` |
| PD intercept rate (0.4) | `combat_system.dart:12` |
| ATK mode range bonus (×1.15) | `combat_system.dart:80` |
| ATK mode damage bonus (×1.25) | `combat_system.dart:128` |
| DEF mode reduction (×0.80) | `combat_system.dart:133` |
| PD range (160.0) | `combat_system.dart:151` |

All are in the same file, which is better than being across files, but they belong in
`lib/data/balance/combat_balance.dart` so they are tunable without opening combat logic.

---

### MODERATE — Selection radius magic number in two files

`40.0` selection radius appears in:
- `lib/game/battle_game.dart:206`
- `lib/ui/screens/deployment_screen.dart` (approx line 388)

---

### MODERATE — Formation offsets embedded in model layer

**File:** `lib/core/models/squad.dart`

Formation geometry (offsets, radii) is computed inside `SquadState.formationOffsets()`.
Model layer should not own geometric configuration. Move to `lib/data/ships/formation_config.dart`.

---

### MINOR — Max speed by mass class is an inline switch

**File:** `lib/core/systems/kinematic_system.dart`

Max speed values (120/80/50/30) are a switch expression embedded in physics logic.
Move to `lib/data/game_config.dart` as `kMaxSpeedByMass`.

---

### MINOR — AI replan intervals in AI implementation file

**File:** `lib/core/ai/doctrine_ai.dart` (lines 17–21)

Move `_aiInterval` map to `lib/data/balance/ai_config.dart`.

---

### MINOR — Faction/UI colors scattered

Player/enemy colors (0xFF4A90D9, 0xFFD94A4A, etc.) appear in multiple rendering and UI files.
Define once in `lib/ui/ui_colors.dart` or `lib/data/game_config.dart`.

---

## Summary Table

| Category | Critical | Moderate | Minor |
|---|---|---|---|
| Security | 0 | 0 | 0 |
| Cleanliness | 0 | 1 | 3 |
| Efficiency | 0 | 3 | 2 |
| Config separation | 0 | 4 | 3 |
| **Total** | **0** | **8** | **8** |

---

## Recommended Pre-M7 Actions

Before implementing new ship types, address in this order:

1. **Create `game_config.dart`** — fix duplicate world dimensions (blocks new screens)
2. **Create `combat_balance.dart`** — new ship tags will add more scattered constants
3. **Update tutorial** — remove references to removed mechanics
4. **Pre-compute alive ship list in combat** — quick fix, good practice before fleet grows

The rest (dashed line cache, AI config file, formation config) can wait for a dedicated
cleanup sprint after M7.
