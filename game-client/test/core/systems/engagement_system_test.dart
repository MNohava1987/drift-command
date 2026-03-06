import 'package:drift_command/core/models/battle_state.dart';
import 'package:drift_command/core/models/ship_data.dart';
import 'package:drift_command/core/models/squad.dart';
import 'package:drift_command/core/systems/command_system.dart';
import 'package:drift_command/core/systems/engagement_system.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

// Minimal ship definitions for tests
const _registry = <String, ShipData>{
  'flagship': ShipData(
    id: 'flagship',
    displayName: 'Flagship',
    role: ShipRole.flagship,
    massClass: MassClass.capital,
    maxAcceleration: 12.0,
    turnRate: 0.4,
    sensorRange: 400.0,
    weaponRange: 120.0,
    maxDurability: 200.0,
    roleTags: [],
  ),
};

BattleState _makeState({
  required SquadState playerSquad,
  required ShipState playerShip,
  required SquadState enemySquad,
  required ShipState enemyShip,
}) {
  return BattleState(
    playerFactionId: 0,
    objectiveDescription: 'test',
    ships: {
      playerShip.instanceId: playerShip,
      enemyShip.instanceId: enemyShip,
    },
    squads: {
      playerSquad.squadId: playerSquad,
      enemySquad.squadId: enemySquad,
    },
    playerFlagshipId: playerShip.instanceId,
    enemyFlagshipId: enemyShip.instanceId,
  );
}

ShipState _ship(String id, String squadId, int faction, Vector2 pos) =>
    ShipState(
      instanceId: id,
      dataId: 'flagship',
      factionId: faction,
      position: pos,
      heading: 0,
      durability: 200,
      squadId: squadId,
    );

SquadState _squad(String id, int faction, Vector2 centroid, EngagementMode mode,
        List<String> shipIds) =>
    SquadState(
      squadId: id,
      type: SquadType.flagship,
      factionId: faction,
      centroid: centroid,
      heading: 0,
      shipInstanceIds: shipIds,
      engagementMode: mode,
    );

void main() {
  late CommandSystem commandSystem;
  late EngagementSystem system;

  setUp(() {
    commandSystem = CommandSystem();
    system = EngagementSystem(commandSystem: commandSystem, registry: _registry);
  });

  test('ENGAGE mode issues attackTarget when player squad within kContactRange', () {
    final pShip = _ship('p_ship_0', 'p_sq', 0, Vector2(500, 300));
    final eShip = _ship('e_ship_0', 'e_sq', 1, Vector2(600, 300));

    final pSq = _squad('p_sq', 0, Vector2(500, 300), EngagementMode.engage, ['p_ship_0']);
    final eSq = _squad('e_sq', 1, Vector2(600, 300), EngagementMode.engage, ['e_ship_0']);
    // Distance = 100, within kContactRange (250)

    final state = _makeState(
      playerSquad: pSq,
      playerShip: pShip,
      enemySquad: eSq,
      enemyShip: eShip,
    );

    system.update(state);

    expect(eSq.activeOrder?.type, OrderType.attackTarget);
    expect(eSq.activeOrder?.targetShipId, 'p_ship_0');
  });

  test('GHOST mode issues moveTo lateral position when contact within range', () {
    final pShip = _ship('p_ship_0', 'p_sq', 0, Vector2(500, 300));
    final eShip = _ship('e_ship_0', 'e_sq', 1, Vector2(600, 300));

    final pSq = _squad('p_sq', 0, Vector2(500, 300), EngagementMode.engage, ['p_ship_0']);
    final eSq = _squad('e_sq', 1, Vector2(600, 300), EngagementMode.ghost, ['e_ship_0']);

    final state = _makeState(
      playerSquad: pSq,
      playerShip: pShip,
      enemySquad: eSq,
      enemyShip: eShip,
    );

    system.update(state);

    expect(eSq.activeOrder?.type, OrderType.moveTo);
    // Target should be lateral (perpendicular to contact direction), not toward player
    final target = eSq.activeOrder!.targetPosition!;
    // Contact direction is along x-axis; perp is along y-axis; so target.x ≈ 600, target.y ≠ 300
    expect((target.y - 300).abs(), greaterThan(50));
  });

  test('DIRECT mode makes no order change regardless of proximity', () {
    final pShip = _ship('p_ship_0', 'p_sq', 0, Vector2(500, 300));
    final eShip = _ship('e_ship_0', 'e_sq', 1, Vector2(510, 300));

    final pSq = _squad('p_sq', 0, Vector2(500, 300), EngagementMode.engage, ['p_ship_0']);
    final eSq = _squad('e_sq', 1, Vector2(510, 300), EngagementMode.direct, ['e_ship_0']);

    final state = _makeState(
      playerSquad: pSq,
      playerShip: pShip,
      enemySquad: eSq,
      enemyShip: eShip,
    );

    system.update(state);

    // No order should be issued for DIRECT mode
    expect(eSq.activeOrder, isNull);
  });

  test('no order when player squad outside kContactRange', () {
    final pShip = _ship('p_ship_0', 'p_sq', 0, Vector2(100, 300));
    final eShip = _ship('e_ship_0', 'e_sq', 1, Vector2(800, 300));

    final pSq = _squad('p_sq', 0, Vector2(100, 300), EngagementMode.engage, ['p_ship_0']);
    final eSq = _squad('e_sq', 1, Vector2(800, 300), EngagementMode.engage, ['e_ship_0']);
    // Distance = 700, outside kContactRange (250)

    final state = _makeState(
      playerSquad: pSq,
      playerShip: pShip,
      enemySquad: eSq,
      enemyShip: eShip,
    );

    system.update(state);

    expect(eSq.activeOrder, isNull);
  });
}
