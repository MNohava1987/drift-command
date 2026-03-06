import 'package:drift_command/core/models/battle_state.dart';
import 'package:drift_command/core/models/ship_data.dart';
import 'package:drift_command/core/systems/tempo_system.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

BattleState _makeBattleState({
  required Vector2 playerPos,
  required Vector2 enemyPos,
}) {
  final player = ShipState(
    instanceId: 'p1',
    dataId: 'flagship',
    factionId: 0,
    position: playerPos,
    heading: 0,
    durability: 100,
  );
  final enemy = ShipState(
    instanceId: 'e1',
    dataId: 'flagship',
    factionId: 1,
    position: enemyPos,
    heading: 0,
    durability: 100,
  );

  return BattleState(
    playerFactionId: 0,
    objectiveDescription: 'Test',
    ships: {'p1': player, 'e1': enemy},
    playerFlagshipId: 'p1',
    enemyFlagshipId: 'e1',
  );
}

void main() {
  test('distant ships produce TempoBand.distant', () {
    final state = _makeBattleState(
      playerPos: Vector2(0, 0),
      enemyPos: Vector2(1000, 0), // very far
    );
    final system = TempoSystem();
    system.update(state, 0.016);
    expect(state.tempoBand, TempoBand.distant);
  });

  test('ships at contact range produce TempoBand.contact', () {
    // weapon range ~150, contact = 2× = 300
    final state = _makeBattleState(
      playerPos: Vector2(0, 0),
      enemyPos: Vector2(250, 0),
    );
    final system = TempoSystem();
    system.update(state, 0.016);
    expect(state.tempoBand, TempoBand.contact);
  });

  test('ships in weapon range produce TempoBand.engaged', () {
    final state = _makeBattleState(
      playerPos: Vector2(0, 0),
      enemyPos: Vector2(100, 0), // inside weapon range
    );
    final system = TempoSystem();
    system.update(state, 0.016);
    expect(state.tempoBand, TempoBand.engaged);
  });

  test('battle time advances on update', () {
    final state = _makeBattleState(
      playerPos: Vector2(0, 0),
      enemyPos: Vector2(1000, 0),
    );
    final system = TempoSystem();
    system.update(state, 1.0);
    expect(state.battleTime, closeTo(1.0, 0.001));
  });
}
