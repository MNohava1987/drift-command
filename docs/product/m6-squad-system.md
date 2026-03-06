# M6 — Squad System Refactor

**Status:** In progress
**Goal:** Replace individual-ship micromanagement with a Mechabellum-style squad system.
Strategy lives in pre-battle deployment and per-squad engagement mode. Player places squads,
sets DIRECT/ENGAGE/GHOST mode, optionally draws a route, hits ENGAGE, watches plan execute.

---

## Design Summary

| Concept | Description |
|---|---|
| Squad | Group of ships with shared centroid, heading, engagement mode |
| Engagement mode | DIRECT (hold route), ENGAGE (attack nearest), GHOST (evade contact) |
| Deployment | Pre-battle screen where player spends budget to place squads |
| Formation | Offsets from centroid, rotated by heading, maintained by SquadSystem |
| AI | Operates at squad level; per-ship role logic removed |

---

## Squad Types

| Type | Ships | Cost | Formation |
|---|---|---|---|
| flagship | flagship ×1 | 0 | single point |
| lineDivision | heavy_line ×2 | 4 | `(-20,0),(20,0)` |
| raidPack | fast_raider ×6 | 2 | hex ring at r=30 |
| carrierStrike | strike_carrier + light_escort ×2 | 5 | `(0,0),(-40,-20),(-40,20)` |
| escortScreen | light_escort ×5 | 3 | V: `(0,0),(-25,-30),(25,-30),(-50,-15),(50,-15)` |

Ship instance IDs: `"{squadId}_ship_{index}"` — e.g. `p_flagship_ship_0`, `e_raid_1_ship_3`

---

## Build Order (each phase must compile + pass tests before starting next)

### Phase 1 — Data Models + Dead Code Removal ✅ (complete)

**Files created:**
- `lib/core/models/squad.dart` (NEW)

**Files modified:**
- `lib/core/models/ship_data.dart` — remove `ShipRole.commandRelay`, add `String? squadId` to `ShipState`
- `lib/core/models/battle_state.dart` — add `Map<String, SquadState> squads`, `int playerBudget`, `List<SquadType> availableSquadTypes`; add convenience getters
- `lib/data/ships/ship_definitions.dart` — delete `command_relay` entry
- `lib/core/ai/doctrine_ai.dart` — remove `commandRelay` case from switch (merge with `lightEscort`)
- `lib/game/components/battlefield_renderer.dart` — remove all `commandRelay` references: `_playerRelay`, `_enemyRelay` constants; commandRelay cases in `_shipPathForRole`, `_radiusForRole`, `_weaponRangeForRole`, `_labelForRole`, `_colorForShip`

**Files deleted:**
- `lib/core/models/command_node.dart`
- `test/core/models/command_node_test.dart`

**Tests updated:**
- `test/core/services/scenario_loader_test.dart` — remove relay ships from inline JSON, adjust ship count to 6 (3 player: flagship/heavy/escort; 3 enemy: flagship/heavy/raider)

#### squad.dart — exact content

```dart
import 'dart:math' as math;
import 'package:flame/components.dart';
import 'ship_data.dart';

enum EngagementMode { direct, engage, ghost }

enum SquadType { flagship, lineDivision, raidPack, carrierStrike, escortScreen }

class SquadState {
  final String squadId;
  final SquadType type;
  final int factionId;

  Vector2 centroid;
  double heading;
  Vector2 velocity;
  EngagementMode engagementMode;
  Order? activeOrder;
  double orderFlashUntil;
  final List<String> shipInstanceIds;

  SquadState({
    required this.squadId,
    required this.type,
    required this.factionId,
    required this.centroid,
    required this.heading,
    required this.shipInstanceIds,
    this.engagementMode = EngagementMode.engage,
    Vector2? velocity,
    this.activeOrder,
    this.orderFlashUntil = -1.0,
  }) : velocity = velocity ?? Vector2.zero();

  static List<Vector2> formationOffsets(SquadType type) {
    switch (type) {
      case SquadType.flagship:
        return [Vector2.zero()];
      case SquadType.lineDivision:
        return [Vector2(-20, 0), Vector2(20, 0)];
      case SquadType.raidPack:
        return List.generate(6, (i) {
          final angle = i * math.pi / 3;
          return Vector2(math.cos(angle) * 30, math.sin(angle) * 30);
        });
      case SquadType.carrierStrike:
        return [Vector2(0, 0), Vector2(-40, -20), Vector2(-40, 20)];
      case SquadType.escortScreen:
        return [
          Vector2(0, 0),
          Vector2(-25, -30),
          Vector2(25, -30),
          Vector2(-50, -15),
          Vector2(50, -15),
        ];
    }
  }

  static List<String> shipDataIds(SquadType type) {
    switch (type) {
      case SquadType.flagship:
        return ['flagship'];
      case SquadType.lineDivision:
        return ['heavy_line', 'heavy_line'];
      case SquadType.raidPack:
        return List.filled(6, 'fast_raider');
      case SquadType.carrierStrike:
        return ['strike_carrier', 'light_escort', 'light_escort'];
      case SquadType.escortScreen:
        return List.filled(5, 'light_escort');
    }
  }

  static int cost(SquadType type) => switch (type) {
        SquadType.flagship => 0,
        SquadType.raidPack => 2,
        SquadType.escortScreen => 3,
        SquadType.lineDivision => 4,
        SquadType.carrierStrike => 5,
      };
}
```

#### ship_data.dart changes

Remove `commandRelay` from `ShipRole` enum:
```dart
enum ShipRole {
  flagship,
  // commandRelay REMOVED
  heavyLine,
  lightEscort,
  strikeCarrier,
  fastRaider,
}
```

Add `String? squadId` to `ShipState` (after `factionId`):
```dart
String? squadId;
```
Add to constructor params: `this.squadId`.

#### battle_state.dart changes

Add import at top: `import 'squad.dart';`

Add to `BattleState` fields:
```dart
final Map<String, SquadState> squads;
final int playerBudget;
final List<SquadType> availableSquadTypes;
```

Add to constructor with defaults:
```dart
this.squads = const {},
this.playerBudget = 0,
this.availableSquadTypes = const [],
```

Add getters:
```dart
Iterable<SquadState> get playerSquads =>
    squads.values.where((sq) => sq.factionId == playerFactionId);

Iterable<SquadState> get enemySquads =>
    squads.values.where((sq) => sq.factionId != playerFactionId);

bool squadIsAlive(SquadState squad) =>
    squad.shipInstanceIds.any((id) => ships[id]?.isAlive == true);

SquadState? get playerFlagshipSquad => squads.values
    .where((sq) => sq.factionId == playerFactionId && sq.type == SquadType.flagship)
    .firstOrNull;
```

#### doctrine_ai.dart change (Phase 1 minimal fix)

In `_applyShipDoctrine` switch, remove `case ShipRole.commandRelay:` and merge it with `lightEscort`:
```dart
case ShipRole.lightEscort:
  // screens flagship (commandRelay behavior merged here)
  if (myFlagship != null) { ... }
```

#### battlefield_renderer.dart changes

1. Delete `static const int _playerRelay = 0xFF6A9AC8;` and `_enemyRelay`
2. In `_colorForShip`: remove the `commandRelay` block
3. In `_radiusForRole`: remove `ShipRole.commandRelay` from switch (merge into `strikeCarrier` case or give it a default)
4. In `_weaponRangeForRole`: remove `commandRelay` case
5. In `_labelForRole`: remove `commandRelay => 'R'` case
6. In `_shipPathForRole`: remove `case ShipRole.commandRelay:` block

Note: All these switches will need to be exhaustive for the 5 remaining ShipRole values.

#### scenario_loader_test.dart — Phase 1 inline JSON (6 ships, no relays)

```json
{
  "id": "scenario_001",
  "objective": "Destroy the enemy flagship",
  "playerFactionId": 0,
  "winCondition": { "type": "destroyEnemyFlagship", "targetShipId": "e_flagship" },
  "ships": [
    { "instanceId": "p_flagship", "dataId": "flagship", "factionId": 0, "position": [150,300], "heading": 0 },
    { "instanceId": "p_heavy", "dataId": "heavy_line", "factionId": 0, "position": [170,360], "heading": 0 },
    { "instanceId": "p_escort", "dataId": "light_escort", "factionId": 0, "position": [200,220], "heading": 0 },
    { "instanceId": "e_flagship", "dataId": "flagship", "factionId": 1, "position": [850,300], "heading": 3.14159 },
    { "instanceId": "e_heavy", "dataId": "heavy_line", "factionId": 1, "position": [830,240], "heading": 3.14159 },
    { "instanceId": "e_raider", "dataId": "fast_raider", "factionId": 1, "position": [760,290], "heading": 3.14159 }
  ]
}
```
Assertions: totalShips=6, playerShips=3, enemyShips=3, playerFlagshipId='p_flagship', enemyFlagshipId='e_flagship'.

---

### Phase 2 — Scenario Format + Loader Rewrite

#### New JSON schema (all 5 scenarios)

Player squads: only flagship placement; player adds rest in deployment screen.
Enemy squads: fully specified with type, position, heading, engagementMode.
Win condition `destroyEnemyFlagship`: loader computes `targetShipId = "{enemyFlagshipSquadId}_ship_0"`.

**scenario_001.json** — First Contact (NORMAL), budget 8
```json
{
  "id": "scenario_001", "name": "First Contact",
  "objective": "Destroy the enemy flagship",
  "playerFactionId": 0, "playerBudget": 8,
  "availableSquadTypes": ["lineDivision","raidPack","escortScreen"],
  "winCondition": { "type": "destroyEnemyFlagship" },
  "factionPostures": { "1": "aggressive" },
  "playerSquads": [
    { "squadId": "p_flagship", "type": "flagship", "position": [200,600], "heading": 0 }
  ],
  "enemySquads": [
    { "squadId": "e_flagship", "type": "flagship", "factionId": 1, "position": [1800,600], "heading": 3.14159, "engagementMode": "engage" },
    { "squadId": "e_line_1", "type": "lineDivision", "factionId": 1, "position": [1650,400], "heading": 3.14159, "engagementMode": "engage" }
  ]
}
```

**scenario_002.json** — Relay Hunt (HARD), budget 8
```json
{
  "id": "scenario_002", "name": "Relay Hunt",
  "objective": "Destroy all enemy forces",
  "playerFactionId": 0, "playerBudget": 8,
  "availableSquadTypes": ["lineDivision","raidPack","escortScreen","carrierStrike"],
  "winCondition": { "type": "destroyAllEnemies" },
  "factionPostures": { "1": "flanking" },
  "playerSquads": [
    { "squadId": "p_flagship", "type": "flagship", "position": [200,600], "heading": 0 }
  ],
  "enemySquads": [
    { "squadId": "e_flagship", "type": "flagship", "factionId": 1, "position": [1800,600], "heading": 3.14159, "engagementMode": "engage" },
    { "squadId": "e_line_1", "type": "lineDivision", "factionId": 1, "position": [1650,350], "heading": 3.14159, "engagementMode": "engage" },
    { "squadId": "e_line_2", "type": "lineDivision", "factionId": 1, "position": [1650,850], "heading": 3.14159, "engagementMode": "engage" },
    { "squadId": "e_raid_1", "type": "raidPack", "factionId": 1, "position": [1550,600], "heading": 3.14159, "engagementMode": "engage" }
  ]
}
```

**scenario_003.json** — Holding Action (BRUTAL), survive 120s, budget 8
```json
{
  "id": "scenario_003", "name": "Holding Action",
  "objective": "Survive for 2 minutes",
  "playerFactionId": 0, "playerBudget": 8,
  "availableSquadTypes": ["lineDivision","escortScreen","carrierStrike"],
  "winCondition": { "type": "surviveUntilTime", "timeLimit": 120 },
  "factionPostures": { "1": "aggressive" },
  "playerSquads": [
    { "squadId": "p_flagship", "type": "flagship", "position": [200,600], "heading": 0 }
  ],
  "enemySquads": [
    { "squadId": "e_flagship", "type": "flagship", "factionId": 1, "position": [1800,600], "heading": 3.14159, "engagementMode": "engage" },
    { "squadId": "e_line_1", "type": "lineDivision", "factionId": 1, "position": [1650,300], "heading": 3.14159, "engagementMode": "engage" },
    { "squadId": "e_line_2", "type": "lineDivision", "factionId": 1, "position": [1650,900], "heading": 3.14159, "engagementMode": "engage" },
    { "squadId": "e_escort_1", "type": "escortScreen", "factionId": 1, "position": [1550,600], "heading": 3.14159, "engagementMode": "engage" },
    { "squadId": "e_raid_1", "type": "raidPack", "factionId": 1, "position": [1700,200], "heading": 3.14159, "engagementMode": "engage" }
  ]
}
```

**scenario_004.json** — Ambush at the Gap (HARD), budget 10
```json
{
  "id": "scenario_004", "name": "Ambush at the Gap",
  "objective": "Destroy the enemy flagship",
  "playerFactionId": 0, "playerBudget": 10,
  "availableSquadTypes": ["lineDivision","raidPack","escortScreen","carrierStrike"],
  "winCondition": { "type": "destroyEnemyFlagship" },
  "factionPostures": { "1": "flanking" },
  "playerSquads": [
    { "squadId": "p_flagship", "type": "flagship", "position": [200,600], "heading": 0 }
  ],
  "enemySquads": [
    { "squadId": "e_flagship", "type": "flagship", "factionId": 1, "position": [1800,600], "heading": 3.14159, "engagementMode": "engage" },
    { "squadId": "e_line_1", "type": "lineDivision", "factionId": 1, "position": [1600,250], "heading": 3.14159, "engagementMode": "engage" },
    { "squadId": "e_line_2", "type": "lineDivision", "factionId": 1, "position": [1600,950], "heading": 3.14159, "engagementMode": "engage" },
    { "squadId": "e_raid_1", "type": "raidPack", "factionId": 1, "position": [1500,400], "heading": 3.14159, "engagementMode": "engage" },
    { "squadId": "e_raid_2", "type": "raidPack", "factionId": 1, "position": [1500,800], "heading": 3.14159, "engagementMode": "engage" }
  ]
}
```

**scenario_005.json** — Last Stand (BRUTAL), survive 240s, budget 12
```json
{
  "id": "scenario_005", "name": "Last Stand",
  "objective": "Survive for 4 minutes",
  "playerFactionId": 0, "playerBudget": 12,
  "availableSquadTypes": ["lineDivision","raidPack","escortScreen","carrierStrike"],
  "winCondition": { "type": "surviveUntilTime", "timeLimit": 240 },
  "factionPostures": { "1": "aggressive" },
  "playerSquads": [
    { "squadId": "p_flagship", "type": "flagship", "position": [200,600], "heading": 0 }
  ],
  "enemySquads": [
    { "squadId": "e_flagship", "type": "flagship", "factionId": 1, "position": [1800,600], "heading": 3.14159, "engagementMode": "engage" },
    { "squadId": "e_line_1", "type": "lineDivision", "factionId": 1, "position": [1650,200], "heading": 3.14159, "engagementMode": "engage" },
    { "squadId": "e_line_2", "type": "lineDivision", "factionId": 1, "position": [1650,500], "heading": 3.14159, "engagementMode": "engage" },
    { "squadId": "e_line_3", "type": "lineDivision", "factionId": 1, "position": [1650,700], "heading": 3.14159, "engagementMode": "engage" },
    { "squadId": "e_line_4", "type": "lineDivision", "factionId": 1, "position": [1650,1000], "heading": 3.14159, "engagementMode": "engage" },
    { "squadId": "e_escort_1", "type": "escortScreen", "factionId": 1, "position": [1550,600], "heading": 3.14159, "engagementMode": "engage" },
    { "squadId": "e_carrier_1", "type": "carrierStrike", "factionId": 1, "position": [1900,600], "heading": 3.14159, "engagementMode": "engage" },
    { "squadId": "e_raid_1", "type": "raidPack", "factionId": 1, "position": [1700,350], "heading": 3.14159, "engagementMode": "engage" },
    { "squadId": "e_raid_2", "type": "raidPack", "factionId": 1, "position": [1700,850], "heading": 3.14159, "engagementMode": "engage" }
  ]
}
```

#### scenario_loader.dart — full rewrite logic

Key points:
- `fromJson` now reads `playerSquads` and `enemySquads` arrays (not `ships`)
- Returns `BattleState` (no wrapper class needed — playerBudget + availableSquadTypes now in BattleState)
- Parses `availableSquadTypes` from JSON strings using `_parseSquadType()`
- For each squad: calls `SquadState.shipDataIds(type)` and `formationOffsets(type)`
- Generates instanceId: `"${squadId}_ship_$i"`
- Computes worldPos: centroid + offset rotated by heading
- Creates `ShipState` with `squadId` set, `durability` = full `data.maxDurability`
- For `destroyEnemyFlagship`: sets `targetShipId = "${enemyFlagshipSquadId}_ship_0"` (finds the squad with type==flagship in enemySquads)
- No carry-damage support (always full health)

Position rotation formula:
```dart
final cosH = math.cos(heading);
final sinH = math.sin(heading);
final rx = offset.x * cosH - offset.y * sinH;
final ry = offset.x * sinH + offset.y * cosH;
final worldPos = Vector2(centroid.x + rx, centroid.y + ry);
```

#### scenario_loader_test.dart — Phase 2 rewrite

Test JSON: flagship squad + raidPack enemy squad + enemy flagship squad
Tests:
- `state.squads.length == 3`
- Enemy raidPack squad has 6 shipInstanceIds
- `state.ships.length == 8` (1 + 1 + 6)
- `state.playerFlagshipId == 'p_flagship_ship_0'`
- `state.enemyFlagshipId == 'e_flagship_ship_0'`
- `state.winCondition!.targetShipId == 'e_flagship_ship_0'`
- `state.playerBudget == 8`

---

### Phase 3 — Squad Movement System

#### lib/core/systems/squad_system.dart (NEW)

```dart
// Called AFTER KinematicSystem.update each tick.
// Per squad:
// 1. Find alive member ships
// 2. Elect leader = first alive ship (index 0 preferred)
// 3. Propagate squad.activeOrder to leader.activeOrder
// 4. Update squad centroid/heading/velocity from leader
// 5. For each non-leader: set ship.activeOrder = Order(moveTo: centroid + rotatedOffset)

class SquadSystem {
  void update(BattleState state) {
    for (final squad in state.squads.values) {
      final members = squad.shipInstanceIds
          .map((id) => state.ships[id])
          .whereType<ShipState>()
          .where((s) => s.isAlive)
          .toList();
      if (members.isEmpty) continue;

      // Leader: prefer index-0 ship, fall back to first alive
      final leader = members.first;

      // Propagate squad order to leader
      if (squad.activeOrder != null) {
        leader.activeOrder = squad.activeOrder;
      }

      // Sync centroid/heading/velocity from leader
      squad.centroid = leader.position.clone();
      squad.heading = leader.heading;
      squad.velocity = leader.velocity.clone();

      // Non-leaders: move to formation position
      final offsets = SquadState.formationOffsets(squad.type);
      for (var i = 1; i < squad.shipInstanceIds.length; i++) {
        final ship = state.ships[squad.shipInstanceIds[i]];
        if (ship == null || !ship.isAlive) continue;
        final offset = i < offsets.length ? offsets[i] : Vector2.zero();
        final cosH = math.cos(squad.heading);
        final sinH = math.sin(squad.heading);
        final targetPos = squad.centroid + Vector2(
          offset.x * cosH - offset.y * sinH,
          offset.x * sinH + offset.y * cosH,
        );
        ship.activeOrder = Order(type: OrderType.moveTo, targetPosition: targetPos, targetSpeedFraction: 1.0);
      }
    }
  }
}
```

#### command_system.dart — add issueSquadOrder

```dart
void issueSquadOrder({
  required BattleState state,
  required String squadId,
  required OrderType orderType,
  Vector2? targetPosition,
  String? targetEnemyId,
  double targetSpeedFraction = 0.5,
}) {
  final squad = state.squads[squadId];
  if (squad == null) return;
  squad.activeOrder = Order(
    type: orderType,
    targetPosition: targetPosition,
    targetShipId: targetEnemyId,
    targetSpeedFraction: targetSpeedFraction,
  );
  squad.orderFlashUntil = state.battleTime + 0.45;
}
```

#### battle_game.dart wiring (Phase 3)

```dart
late final SquadSystem _squadSystem;
// in onLoad():
_squadSystem = SquadSystem();

// in update():
// 1. _tempoSystem.update
// 2. _ai.update
// 3. _kinematics.update(aliveShips)
// 4. _squadSystem.update(_state)   ← insert here
// 5. _combat.update
```

#### squad_system_test.dart tests

1. Centroid follows leader position after update
2. Follower ship gets moveTo order with correct rotated offset
3. Dead leader triggers re-election (next alive ship becomes effective leader)

---

### Phase 4 — Engagement Mode + AI Rewrite

#### lib/core/systems/engagement_system.dart (NEW)

```dart
const double kContactRange = 250.0;

class EngagementSystem {
  final CommandSystem commandSystem;
  final Map<String, ShipData> registry;

  void update(BattleState state) {
    for (final squad in state.squads.values) {
      if (!state.squadIsAlive(squad)) continue;
      if (squad.factionId == state.playerFactionId) continue; // AI squads only

      // Find nearest enemy (player) squad centroid
      SquadState? nearest;
      double nearestDist = double.infinity;
      for (final playerSquad in state.playerSquads) {
        if (!state.squadIsAlive(playerSquad)) continue;
        final d = squad.centroid.distanceTo(playerSquad.centroid);
        if (d < nearestDist) { nearestDist = d; nearest = playerSquad; }
      }
      if (nearest == null || nearestDist > kContactRange) continue;

      switch (squad.engagementMode) {
        case EngagementMode.direct:
          break; // no change
        case EngagementMode.engage:
          // Attack nearest enemy squad leader ship
          final leaderShip = state.ships[nearest.shipInstanceIds.firstOrNull ?? ''];
          if (leaderShip != null && leaderShip.isAlive) {
            commandSystem.issueSquadOrder(
              state: state, squadId: squad.squadId,
              orderType: OrderType.attackTarget,
              targetPosition: leaderShip.position.clone(),
              targetEnemyId: leaderShip.instanceId,
            );
          }
        case EngagementMode.ghost:
          // Lateral evasion: 180 units perpendicular to contact direction
          final toContact = nearest.centroid - squad.centroid;
          if (toContact.length > 0.1) {
            final perp = Vector2(-toContact.y, toContact.x).normalized() * 180;
            commandSystem.issueSquadOrder(
              state: state, squadId: squad.squadId,
              orderType: OrderType.moveTo,
              targetPosition: squad.centroid + perp,
            );
          }
      }
    }
  }
}
```

#### doctrine_ai.dart — squad-level rewrite

New structure: operates on squads, not individual ships.

```
void update(BattleState state, double dt):
  - tempo-gate
  - for each enemy faction: _runFactionAI(state, factionId)

void _runFactionAI(BattleState state, int factionId):
  - get enemy squads for faction
  - playerFlagshipSquad = state.playerFlagshipSquad
  - posture = state.factionPostures[factionId] ?? aggressive
  - for each squad: set shipMode on all members; apply posture override

Posture logic per squad:
  - aggressive: issueSquadOrder(attackTarget, player flagship squad leader)
  - defensive: hold unless player squad within 200 units
  - flanking: moveTo 150 units lateral from player flagship centroid
  - holdAndFire: hold
```

Note: `engagementSystem.update()` runs at AI tick (not every frame), only for squads without posture-overridden orders.

#### battle_game.dart wiring (Phase 4)

```dart
late final EngagementSystem _engagementSystem;

// in onLoad():
_engagementSystem = EngagementSystem(commandSystem: _commandSystem, registry: kShipDefinitions);
_ai = DoctrineAI(commandSystem: _commandSystem, engagementSystem: _engagementSystem, registry: kShipDefinitions);
```

#### engagement_system_test.dart tests

1. ENGAGE mode issues attackTarget when player squad within kContactRange
2. GHOST mode issues moveTo lateral position when contact within range
3. DIRECT mode makes no order change regardless of proximity

---

### Phase 5 — Deployment Screen

#### lib/ui/screens/deployment_screen.dart (NEW)

`StatefulWidget` using `CustomPaint` canvas + sidebar column.

Canvas (world 2000×1200, letterboxed):
- Right half (x 1000-2000): enemy squad positions, faint red outlines
- Left half (x 0-1000): player deployment zone, grid
- Placed player squads: formation ship outlines at correct positions
- Drag to reposition; tap to select

Sidebar:
- Available squad types from `state.availableSquadTypes`
- Cost badge per type
- Remaining budget counter (budget − sum of placed costs)
- RESET / DEPLOY buttons

Per-selected-squad controls:
- [D] [E] [G] engagement mode toggle
- Rotate heading buttons (± π/8)

On DEPLOY:
- Add player's placed squads + their ships to the initial BattleState (which already has enemy squads + ships)
- Navigate to `GameScreen(initialState: state)`

Constructor: receives `scenarioAssetPath`, loads JSON → initial BattleState (enemy squads placed, player flagship placed).

#### battle_game.dart changes (Phase 5)

```dart
BattleGame({
  this.scenarioAssetPath = 'assets/scenarios/scenario_001.json',
  this.initialState, // NEW: if set, skip JSON loading
});

final BattleState? initialState;

// in onLoad():
if (initialState != null) {
  _state = initialState!;
} else {
  // existing JSON load path
}
```

#### scenario_picker_screen.dart change (Phase 5)

```dart
// Old:
builder: (_) => GameScreen(scenarioId: s.id, scenarioAssetPath: s.assetPath)

// New:
builder: (_) => DeploymentScreen(scenarioAssetPath: s.assetPath, scenarioId: s.id)
```

---

### Phase 6 — HUD + Renderer

#### hud_overlay.dart changes

- Replace `ValueListenableBuilder<ShipState?>` → `ValueListenableBuilder<SquadState?>`
- Replace `selectedShipNotifier` → `selectedSquadNotifier` in BattleGame
- `_ActionBar`: show when squad selected, same HOLD/RETREAT/CANCEL buttons (now call squad versions)
- `_ShipInfoBar` → `_SquadInfoBar`:
  - Squad type label
  - Aggregate HP bar (sum alive ship durability / sum max durability)
  - Engagement mode toggle [D] [E] [G]
  - Active order display

#### battle_game.dart changes (Phase 6)

```dart
// Replace:
ShipState? _selectedShip;
final selectedShipNotifier = ValueNotifier<ShipState?>(null);
ShipState? get selectedShipState => _selectedShip;

// With:
SquadState? _selectedSquad;
final selectedSquadNotifier = ValueNotifier<SquadState?>(null);
SquadState? get selectedSquadState => _selectedSquad;

// onTapDown: select squad by centroid proximity (60-unit radius)
// issueHold/issueRetreat/cancelOrders: delegate to issueSquadOrder
// Add: setEngagementMode(squadId, mode)
```

#### battlefield_renderer.dart changes (Phase 6)

Remove:
- `_drawCommandChainLines` method
- `_playerRelay`, `_enemyRelay` color constants (already done Phase 1)
- Per-ship `_drawOrderLines` → replaced by squad route lines

Add:
- `_drawSquadBoundaries(canvas, state)`: faint ellipse per squad; engagement mode badge (D/E/G) in corner; selection highlight ring for selected squad
- `_drawSquadRoutes(canvas, state)`: line from centroid to activeOrder target; color by mode: DIRECT=white, ENGAGE=cyan, GHOST=gold
- Update `_drawShips` selection check: `ship.squadId == selectedSquad?.squadId`

Update `render()` call sequence:
```dart
_drawBackground
_drawTacticalGrid
_drawSquadBoundaries    // replaces _drawCommandChainLines
_drawTrajectories
_drawSensorGhosts
_drawSquadRoutes        // replaces _drawOrderLines
_drawShips
_drawProjectiles
_drawParticles
_drawTransitPulses
```

---

## File Change Summary

| File | Action |
|---|---|
| `lib/core/models/squad.dart` | NEW (Phase 1) |
| `lib/core/systems/squad_system.dart` | NEW (Phase 3) |
| `lib/core/systems/engagement_system.dart` | NEW (Phase 4) |
| `lib/ui/screens/deployment_screen.dart` | NEW (Phase 5) |
| `lib/core/models/ship_data.dart` | Remove commandRelay, add squadId (Phase 1) |
| `lib/core/models/battle_state.dart` | Add squads map + getters + budget (Phase 1) |
| `lib/core/models/command_node.dart` | DELETE (Phase 1) |
| `lib/core/services/scenario_loader.dart` | Full rewrite (Phase 2) |
| `lib/core/systems/command_system.dart` | Add issueSquadOrder (Phase 3) |
| `lib/core/ai/doctrine_ai.dart` | Minimal fix Phase 1; squad rewrite Phase 4 |
| `lib/data/ships/ship_definitions.dart` | Remove command_relay (Phase 1) |
| `lib/game/battle_game.dart` | Squad system wiring (Phase 3, 4, 5, 6) |
| `lib/game/components/battlefield_renderer.dart` | Remove commandRelay Phase 1; squad visuals Phase 6 |
| `lib/ui/widgets/hud_overlay.dart` | Squad HUD (Phase 6) |
| `lib/ui/screens/scenario_picker_screen.dart` | Route to deployment (Phase 5) |
| `assets/scenarios/*.json` | All 5 rewritten (Phase 2) |
| `test/core/models/command_node_test.dart` | DELETE (Phase 1) |
| `test/core/services/scenario_loader_test.dart` | Phase 1 update; Phase 2 full rewrite |
| `test/core/systems/squad_system_test.dart` | NEW (Phase 3) |
| `test/core/systems/engagement_system_test.dart` | NEW (Phase 4) |

---

## Key Implementation Notes

### Rotation convention
World uses screen coords (y-down). Heading 0 = east. Rotation:
```dart
final rx = offset.x * cos(heading) - offset.y * sin(heading);
final ry = offset.x * sin(heading) + offset.y * cos(heading);
```

### Flagship instance ID
Player flagship always: `"p_flagship_ship_0"`
Enemy flagship: `"{enemyFlagshipSquadId}_ship_0"` — loader computes this for win condition.

### SquadSystem vs KinematicSystem ordering
SquadSystem runs AFTER KinematicSystem. Followers target leader's current-tick position. Lag is intentional (physics-realistic turns).

### Dead leader re-election
Leader is always `shipInstanceIds[0]` if alive. If dead, SquadSystem picks first alive ship in the list (by iterating `shipInstanceIds` in order). No special logic needed — `members.first` after filtering alive ships handles it.

### Deployment screen initial state
The deployment screen loads the scenario JSON to get the initial BattleState (which has enemy squads + ships + player flagship squad + flagship ship). The player adds more squads during deployment. On DEPLOY, the merged BattleState is passed to BattleGame as `initialState`.

### game_screen.dart carry-damage
The Phase 2 loader removes carry-damage support (always full health). The `game_screen.dart` carry-damage path stays in code but is effectively unused since the new loader ignores those params. Full removal can happen in a future cleanup pass.
