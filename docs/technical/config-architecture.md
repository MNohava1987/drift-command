# Drift Command — Config / Code Separation

**Status:** Current state is mixed. This document defines the target state
and the migration plan.

---

## Problem Statement

Game balance values, combat modifiers, visual constants, and tactical thresholds
are currently scattered across ~8 files. This creates two problems:

1. **Tuning requires touching code**, not config — making balance changes riskier
2. **Values duplicated across files** — world width defined in both
   `battlefield_renderer.dart` and `deployment_screen.dart`, for example

---

## Principle: Where Does Each Type of Value Live?

| Value Type | Where It Lives | Why |
|---|---|---|
| Game balance (DPS, HP, ranges, costs) | `lib/data/` | Tunable, data-owned, not logic |
| Visual constants (colors, sizes) | `lib/data/` or top of rendering file | Readable, grouped |
| World/physics constants (world size, sensor speed) | `lib/data/game_config.dart` | Shared, single source |
| Per-ship stats | `lib/data/ships/ship_definitions.dart` | Already correct |
| Formation geometry | `lib/data/ships/formation_config.dart` | Target state (not yet separated) |
| AI behavior intervals | `lib/data/ai_config.dart` | Target state (not yet separated) |
| Scenario content | `assets/scenarios/*.json` | Already correct |

---

## Target File Structure

```
lib/
  data/
    game_config.dart          ← World dimensions, selection radius, render constants
    ships/
      ship_definitions.dart   ← Per-ship stats (already exists, correct)
      formation_config.dart   ← Formation offsets per SquadType (MOVE FROM squad.dart)
    balance/
      combat_balance.dart     ← DPS values, damage modifiers, PD intercept rate
      ai_config.dart          ← AI re-plan intervals per TempoBand
```

---

## Specific Migrations Required

### 1. `lib/data/game_config.dart` (CREATE)

Move from their current locations:

```dart
// From battlefield_renderer.dart AND deployment_screen.dart
const double kWorldWidth = 2000.0;
const double kWorldHeight = 1200.0;

// From battle_game.dart (onTapDown) AND deployment_screen.dart
const double kSelectionRadius = 40.0;

// From battlefield_renderer.dart
const double kTrajectorySeconds = 8.0;
const double kSensorSpeed = 400.0;      // units/second sensor delay

// From engagement_system.dart
const double kContactRange = 250.0;

// From tempo_system.dart
const double kRepresentativeWeaponRange = 150.0;
```

Files that currently define these: `battlefield_renderer.dart`,
`deployment_screen.dart`, `engagement_system.dart`, `tempo_system.dart`,
`battle_game.dart`. After migration, they all import `game_config.dart`.

---

### 2. `lib/data/balance/combat_balance.dart` (CREATE)

Move from `combat_system.dart`:

```dart
// Weapon DPS by tag
const Map<RoleTag, double> kWeaponDps = {
  RoleTag.directFire: 8.0,
  RoleTag.missile: 15.0,
  RoleTag.pointDefense: 5.0,
};

// Modifier constants
const double kPointDefenseInterceptRate = 0.4;  // 40% missile reduction
const double kAttackModeOutgoingBonus = 1.25;   // ATK mode: +25% damage
const double kDefensiveModeIncomingReduction = 0.80; // DEF mode: -20% damage received
const double kAttackModeRangeBonus = 1.15;      // ATK mode weapon range bonus
const double kFlankingDamageBonus = 1.35;       // Flanking tag: +35% from rear arc
const double kHeavyBroadsideBonus = 1.40;       // Dreadnought broadside bonus
const double kPointDefenseRange = 160.0;        // PD coverage radius
const double kRepairRange = 120.0;              // Repair Tender heal radius
const double kRepairHps = 6.0;                  // HP healed per second
const double kJammingRange = 150.0;             // EW Cruiser jam radius
const double kJammingRangePenalty = 0.35;       // Range cut fraction (×0.65 effective)
const double kTorpedoReloadTime = 5.0;          // Torpedo boat reload in seconds
const double kTorpedoSalvoMultiplier = 3.0;     // Burst damage multiplier
const double kFlakAreaRadius = 60.0;            // Flak frigate area burst radius
```

---

### 3. `lib/data/balance/ai_config.dart` (CREATE)

Move from `doctrine_ai.dart`:

```dart
const Map<TempoBand, double> kAiReplanInterval = {
  TempoBand.distant: 15.0,
  TempoBand.contact: 7.0,
  TempoBand.engaged: 3.0,
};

// Flanking posture lateral offset distance
const double kFlankingLateralOffset = 150.0;
// Defensive posture trigger range (hold if no player within this distance)
const double kDefensiveHoldRange = 200.0;
// GHOST engagement mode lateral evade distance
const double kGhostEvadeDistance = 180.0;
```

---

### 4. `lib/data/ships/formation_config.dart` (CREATE)

Move formation geometry from `squad.dart`:

```dart
// Formation offsets per SquadType, keyed by type.
// Offsets are in local squad space — rotated by squad.heading at runtime.
const Map<SquadType, List<Vector2>> kFormationOffsets = {
  SquadType.flagship: [Vector2.zero()],
  SquadType.lineDivision: [Vector2(-20, 0), Vector2(20, 0)],
  SquadType.raidPack: [ /* 6-point ring at radius 30 */ ],
  // ...
};
```

Note: Vector2 is not const-constructible in Dart. Use a factory method or
lazy-init approach rather than a literal map.

---

### 5. Max Speed by Mass Class

Currently in `kinematic_system.dart` as an inline switch:

```dart
MassClass.light => 120.0,
MassClass.medium => 80.0,
MassClass.heavy => 50.0,
MassClass.capital => 30.0,
```

Move to `game_config.dart` as:

```dart
const Map<MassClass, double> kMaxSpeedByMass = {
  MassClass.light: 120.0,
  MassClass.medium: 80.0,
  MassClass.heavy: 50.0,
  MassClass.capital: 30.0,
};
```

---

### 6. Color Scheme

Currently scattered across `battlefield_renderer.dart`, `game_screen.dart`,
`hud_overlay.dart`, `deployment_screen.dart`.

Create a constants section at the top of `battlefield_renderer.dart` or in
`lib/ui/ui_colors.dart`:

```dart
// Faction colors
const Color kPlayerBase = Color(0xFF4A90D9);
const Color kPlayerFlagship = Color(0xFF74B4FF);
const Color kEnemyBase = Color(0xFFD94A4A);
const Color kEnemyFlagship = Color(0xFFFF7474);

// UI accent colors
const Color kOrderCyan = Color(0xFF00FFFF);
const Color kEngageRed = Color(0xFFD94A3A);
const Color kDirectCyan = Color(0xFF00CCCC);
const Color kGhostPurple = Color(0xFF9999CC);
```

---

## Sound Asset Names

Currently hardcoded strings in `battle_game.dart`. Move to `game_config.dart`:

```dart
const String kSoundOrderClick = 'order_click.ogg';
const String kSoundWeaponFire = 'weapon_fire.ogg';
const String kSoundExplosion = 'explosion.ogg';
const String kSoundEngineHum = 'engine_hum.ogg';
```

---

## Migration Priority

Do this migration **before** implementing the new ship roster.
Adding new ships with the current scattered constants makes the problem worse.

| Priority | Task | Risk if deferred |
|---|---|---|
| 1 | Create `game_config.dart` with world dims + selection radius | Duplicate world sizes will diverge with new screens |
| 2 | Create `combat_balance.dart` | New ship tags will add more scattered constants |
| 3 | Move sound names to constants | Minor — strings rarely change |
| 4 | Move max speed by mass to config | Minor — rarely changes |
| 5 | Create `ai_config.dart` | Low — only matters when tuning AI |
| 6 | Move formation offsets to `formation_config.dart` | Medium — new squad types need new offsets |

---

## What Stays in Code (Not Config)

Some values belong in code because they are structural, not tunable:

- `TempoBand` enum values (structural)
- `EngagementMode` enum values (structural)
- `ShipRole` enum values (structural)
- Formation offset computation logic (math in SquadSystem)
- Combat resolution logic (which tags do what — the logic, not the numbers)

The rule: **numbers are config, logic is code.**
