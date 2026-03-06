# M7 Implementation Todo

**Start here:** Read `docs/product/ship-roster.md` and `docs/technical/config-architecture.md`
before touching any code.

Gate rule: `flutter analyze --fatal-infos` + `flutter test` must pass after every phase.
Flutter binary in WSL: `/snap/bin/flutter`

---

## Phase 1 — Config Separation (prerequisite, do this first)

### 1a. Create `lib/data/game_config.dart`

Move these values from wherever they currently live into this single file:

```dart
const double kWorldWidth = 2000.0;          // from battlefield_renderer.dart AND deployment_screen.dart
const double kWorldHeight = 1200.0;         // same
const double kSelectionRadius = 40.0;       // from battle_game.dart AND deployment_screen.dart
const double kTrajectorySeconds = 8.0;      // from battlefield_renderer.dart
const double kSensorSpeed = 400.0;          // from battlefield_renderer.dart
const double kContactRange = 250.0;         // from engagement_system.dart
const double kRepresentativeWeaponRange = 150.0; // from tempo_system.dart

const Map<MassClass, double> kMaxSpeedByMass = {
  MassClass.light: 120.0,
  MassClass.medium: 80.0,
  MassClass.heavy: 50.0,
  MassClass.capital: 30.0,
};

const String kSoundOrderClick  = 'order_click.ogg';
const String kSoundWeaponFire  = 'weapon_fire.ogg';
const String kSoundExplosion   = 'explosion.ogg';
const String kSoundEngineHum   = 'engine_hum.ogg';
```

Files to update (import `game_config.dart` and remove their local defs):
- `lib/game/components/battlefield_renderer.dart`
- `lib/ui/screens/deployment_screen.dart`
- `lib/game/battle_game.dart`
- `lib/core/systems/engagement_system.dart`
- `lib/core/systems/tempo_system.dart`
- `lib/core/systems/kinematic_system.dart`

### 1b. Create `lib/data/balance/combat_balance.dart`

Move from `lib/core/systems/combat_system.dart`:

```dart
const Map<RoleTag, double> kWeaponDps = {
  RoleTag.directFire: 8.0,
  RoleTag.missile: 15.0,
  RoleTag.pointDefense: 5.0,
};
const double kPointDefenseInterceptRate = 0.4;
const double kAttackModeRangeBonus      = 1.15;
const double kAttackModeDamageBonus     = 1.25;
const double kDefensiveModeReduction    = 0.80;
const double kPointDefenseRange         = 160.0;
```

New values to add here (used by new ship mechanics in Phase 2):
```dart
const double kTorpedoReloadTime       = 5.0;
const double kTorpedoSalvoMultiplier  = 3.0;
const double kRepairRange             = 120.0;
const double kRepairHps               = 6.0;
const double kJammingRange            = 150.0;
const double kJammingRangePenalty     = 0.35;   // effective range × (1 - 0.35)
const double kFlakAreaRadius          = 60.0;
const double kFlankingDamageBonus     = 1.35;
const double kHeavyBroadsideBonus     = 1.40;
```

### 1c. Create `lib/data/balance/ai_config.dart`

Move from `lib/core/ai/doctrine_ai.dart`:

```dart
const Map<TempoBand, double> kAiReplanInterval = {
  TempoBand.distant: 15.0,
  TempoBand.contact: 7.0,
  TempoBand.engaged: 3.0,
};
const double kFlankingLateralOffset = 150.0;
const double kDefensiveHoldRange    = 200.0;
const double kGhostEvadeDistance    = 180.0;
```

### 1d. Gate check

```
/snap/bin/flutter analyze --fatal-infos
/snap/bin/flutter test
```

Both must pass before Phase 2.

---

## Phase 2 — New Ship Data (no combat logic yet)

### 2a. Update `lib/core/models/ship_data.dart`

Add to `ShipRole` enum:
```dart
gunboat, interceptor, flakFrigate, destroyer, heavyCruiser,
ewCruiser, repairTender, battlecruiser, dreadnought
```

Add to `RoleTag` enum:
```dart
torpedo, intercept, flak, jamming, repair, heavyBroadside
```

Note: `flanking` already exists but currently does nothing — Phase 3 will activate it.

### 2b. Update `lib/data/ships/ship_definitions.dart`

Add all new hull entries. Reference stats from `docs/product/ship-roster.md`.
Use the new `RoleTag` values added in 2a.

Rename existing hulls to match roster:
- `heavy_line` → `heavy_cruiser` (update key string, displayName, role enum)
- `light_escort` → `interceptor` (update key string, displayName, role enum, tags)
- `fast_raider` → `gunboat` (update key string, displayName, role enum)

**Warning:** Renaming hull IDs breaks SharedPrefs durability fractions.
After rename, also update `game_screen.dart`'s `_saveDurabilityFractions` — the prefs
key is `'durability_fraction_${ship.dataId}'`, so old saved data becomes orphaned.
That's acceptable — it's dev data.

### 2c. Update `lib/core/models/squad.dart`

Add to `SquadType` enum:
```dart
gunboatPack, interceptorScreen, flakLine, torpedoRun,
cruiserDivision, ewFlight, supportGroup, carrierGroup,
battlecruiserGroup, dreadnoughtGroup
```

Update `formationOffsets()` switch with offsets for each new type.
Update `shipDataIds()` switch with hull IDs for each new type.
Update `cost()` switch with costs per `ship-roster.md`.

### 2d. Update `lib/game/components/battlefield_renderer.dart`

Add ship shapes to `_shipPathForRole()` for each new ShipRole.
Add labels to `_labelForRole()`: G, I, K, D, H, W, R, B, N
Add radii to `_radiusForRole()`.
Add weapon ranges to `_weaponRangeForRole()`.

### 2e. Gate check

```
/snap/bin/flutter analyze --fatal-infos
/snap/bin/flutter test
```

---

## Phase 3 — Combat Mechanics

All changes in `lib/core/systems/combat_system.dart` (import `combat_balance.dart`).

### 3a. Per-ship torpedo state

Add to `ShipState` in `ship_data.dart`:
```dart
double torpedoReloadUntil = 0.0;  // battle time when torpedo is ready again
```

### 3b. Implement torpedo salvo in `_applyDamage()`

When attacker has `RoleTag.torpedo`:
- Check `attacker.torpedoReloadUntil <= state.battleTime`
- If ready: apply `kTorpedoSalvoMultiplier × kWeaponDps[directFire] × dt` as a burst,
  set `attacker.torpedoReloadUntil = state.battleTime + kTorpedoReloadTime`
- If reloading: skip (no damage)
- Torpedo damage ignores `_hasNearbyPointDefense()` check entirely

### 3c. Implement repair aura

In `update()`, after damage loop, add a repair pass:
```dart
for each ship with RoleTag.repair that is alive:
  for each allied ship within kRepairRange:
    target.durability = min(target.durability + kRepairHps * dt, maxDurability)
```

### 3d. Implement jamming range modifier

In `_selectTarget()`, when computing `effectiveRange`:
```dart
// Check if attacker is inside any enemy EW Cruiser jamming field
bool jammed = state.ships.values.any((s) =>
    s.isAlive &&
    s.factionId != attacker.factionId &&
    (registry[s.dataId]?.roleTags.contains(RoleTag.jamming) ?? false) &&
    s.position.distanceTo(attacker.position) <= kJammingRange);
if (jammed) effectiveRange *= (1.0 - kJammingRangePenalty);
```

### 3e. Implement flak area damage

Ships with `RoleTag.flak` damage ALL ships (ally + enemy) within `kFlakAreaRadius`:
```dart
if (data.roleTags.contains(RoleTag.flak)) {
  for each ship within kFlakAreaRadius of attacker (including allies, excluding self):
    ship.durability -= kWeaponDps[directFire] * dt
    ship.lastHitAt = state.battleTime
}
```
Do not apply flak damage through `_applyDamage()` — handle in a separate pass.

### 3f. Implement flanking damage bonus

In `_applyDamage()`, after base damage is computed:
```dart
if (data.roleTags.contains(RoleTag.flanking)) {
  // Angle between (attacker→target vector) and target's heading
  final toTarget = attacker.position - target.position;
  final targetFwd = Vector2(cos(target.heading), sin(target.heading));
  final dot = toTarget.normalized().dot(targetFwd);
  // dot < 0 means attacker is behind the target (rear arc)
  if (dot < 0) damage *= kFlankingDamageBonus;
}
```

### 3g. Implement heavyBroadside bonus

In `_applyDamage()`:
```dart
if (data.roleTags.contains(RoleTag.heavyBroadside)) {
  final toTarget = (target.position - attacker.position).normalized();
  final attackerFwd = Vector2(cos(attacker.heading), sin(attacker.heading));
  final perp = (toTarget.dot(attackerFwd)).abs(); // 0=perpendicular, 1=head-on
  // Broadside bonus scales: max at perpendicular (perp≈0), zero at head-on (perp≈1)
  final broadsideFactor = 1.0 + kHeavyBroadsideBonus * (1.0 - perp);
  damage *= broadsideFactor;
}
```

### 3h. Implement intercept targeting preference

In `_selectTarget()`, if attacker has `RoleTag.intercept`:
- Prefer enemies with `RoleTag.missile` in their tags (Strike Carriers)
- If a missile carrier is in range, always return it over a closer non-carrier

### 3i. Write/update tests

Create `test/core/systems/combat_system_test.dart` covering:
- Torpedo does burst damage and then reloads (no damage during reload)
- Torpedo ignores point defense
- Repair tender heals ally within range
- Repair tender does not heal enemies
- Jamming reduces effective range
- Flak damages ships within area radius (including allies)
- Flanking bonus applies from rear arc, not front
- Interceptor prefers missile carrier targets

### 3j. Gate check

```
/snap/bin/flutter analyze --fatal-infos
/snap/bin/flutter test
```

---

## Phase 4 — Scenario Updates

### 4a. Update scenario JSON files

All 5 scenarios need `availableSquadTypes` updated to include new squad types.
Later scenarios (003, 004, 005) should have new enemy squad types:
- 003 (Holding Action): add enemy `cruiserDivision` and `supportGroup`
- 004 (Ambush at the Gap): add enemy `torpedoRun`
- 005 (Last Stand): add enemy `dreadnoughtGroup` and `battlecruiserGroup`

Reference: `assets/scenarios/scenario_00X.json`

### 4b. Update scenario_loader.dart if needed

New squad types should parse automatically if `_parseSquadType()` switch covers them.
Add missing cases for all new `SquadType` enum values.

### 4c. Update scenario_loader_test.dart

Verify new squad types load and generate correct ship counts.

### 4d. Gate check

```
/snap/bin/flutter analyze --fatal-infos
/snap/bin/flutter test
```

---

## Phase 5 — Tutorial Update

### 5a. Update `lib/ui/screens/tutorial_screen.dart`

Remove: references to command windows, pulse gating (removed in M2/M3).
Add: squad system overview, deployment screen explanation, engagement modes (D/E/G),
how to read squad boundaries and mode badges on the battlefield.

---

## Phase 6 — Deployment Screen Update

### 6a. Update `lib/ui/screens/deployment_screen.dart`

The sidebar ADD SQUAD buttons are currently hardcoded to 5 squad types.
With 10+ squad types, this needs a scrollable list or a tiered layout.

Suggested: group by tier (Flak / Line / Capital) with section headers.
Show cost prominently. Show ship count and hull types per squad.

---

## Acceptance Criteria (M7 Done When)

- [ ] All 11 hull types defined in `ship_definitions.dart`
- [ ] All new squad types in `squad.dart` with correct formation offsets and costs
- [ ] All new combat mechanics in `combat_system.dart` (torpedo, repair, jam, flak, flanking, broadside)
- [ ] New ship shapes visible in battlefield renderer
- [ ] Deployment screen shows all squad types in a usable layout
- [ ] Scenarios 003/004/005 have new enemy squad types
- [ ] `flutter analyze --fatal-infos` clean
- [ ] `flutter test` passes (target: 38+ tests — add ~10 combat mechanic tests)
- [ ] Config constants live in `game_config.dart` and `combat_balance.dart`, not inline

---

## Key Files Reference

| What | Where |
|---|---|
| Ship stats | `lib/data/ships/ship_definitions.dart` |
| ShipRole + RoleTag enums | `lib/core/models/ship_data.dart` |
| SquadType + formation offsets | `lib/core/models/squad.dart` |
| Combat mechanics | `lib/core/systems/combat_system.dart` |
| World/tactical config | `lib/data/game_config.dart` (create in Phase 1) |
| Balance values | `lib/data/balance/combat_balance.dart` (create in Phase 1) |
| Ship shapes + labels | `lib/game/components/battlefield_renderer.dart` |
| Deployment screen | `lib/ui/screens/deployment_screen.dart` |
| Scenario JSON | `assets/scenarios/scenario_00X.json` |
| Design reference | `docs/product/ship-roster.md` |
| Balance reference | `docs/product/game-balance.md` |
| Code review findings | `docs/technical/code-review-m6.md` |
| Config migration plan | `docs/technical/config-architecture.md` |

## Flutter / tooling

- Test run: `/snap/bin/flutter test`
- Analyze: `/snap/bin/flutter analyze --fatal-infos`
- Run on device: `flutter run -d emulator-5554` (from Windows terminal in game-client dir)
- Hot restart required for Dart changes (not hot reload)
