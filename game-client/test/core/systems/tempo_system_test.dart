import 'package:drift_command/core/models/battle_state.dart';
import 'package:drift_command/core/models/ship_data.dart';
import 'package:drift_command/core/models/command_node.dart';
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
    topologies: {
      0: CommandTopology(
        factionId: 0,
        flagshipNodeId: 'n0',
        nodes: {
          'n0': CommandNode(
            nodeId: 'n0',
            shipInstanceId: 'p1',
            type: CommandNodeType.flagship,
          ),
        },
      ),
      1: CommandTopology(
        factionId: 1,
        flagshipNodeId: 'n1',
        nodes: {
          'n1': CommandNode(
            nodeId: 'n1',
            shipInstanceId: 'e1',
            type: CommandNodeType.flagship,
          ),
        },
      ),
    },
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

  test('command pulse is ready at t=0 (nextCommandPulse starts at 0)', () {
    final state = _makeBattleState(
      playerPos: Vector2(0, 0),
      enemyPos: Vector2(1000, 0),
    );
    final system = TempoSystem();
    expect(system.isCommandPulseReady(state), isTrue);
  });

  test('advanceCommandPulse closes the window', () {
    final state = _makeBattleState(
      playerPos: Vector2(0, 0),
      enemyPos: Vector2(1000, 0),
    );
    final system = TempoSystem();
    system.update(state, 0.016);
    expect(system.isCommandPulseReady(state), isTrue);

    system.advanceCommandPulse(state);
    expect(system.isCommandPulseReady(state), isFalse);
  });

  test('pulse re-opens after band duration elapses', () {
    final state = _makeBattleState(
      playerPos: Vector2(0, 0),
      enemyPos: Vector2(1000, 0), // distant band: 15s pulse
    );
    final system = TempoSystem();
    system.update(state, 0.016);
    system.advanceCommandPulse(state); // close window

    // Advance less than pulse duration — still closed
    system.update(state, 10.0);
    expect(system.isCommandPulseReady(state), isFalse);

    // Advance past pulse duration — now open
    system.update(state, 6.0);
    expect(system.isCommandPulseReady(state), isTrue);
  });

  test('band change resets pulse immediately', () {
    final state = _makeBattleState(
      playerPos: Vector2(0, 0),
      enemyPos: Vector2(1000, 0),
    );
    final system = TempoSystem();
    system.update(state, 0.016);
    system.advanceCommandPulse(state); // close window

    // Move ships close — band changes to engaged
    state.ships['p1']!.position = Vector2(0, 0);
    state.ships['e1']!.position = Vector2(50, 0);
    system.update(state, 0.016);

    // Band change should have reset nextCommandPulse to current time
    expect(system.isCommandPulseReady(state), isTrue);
  });
}
