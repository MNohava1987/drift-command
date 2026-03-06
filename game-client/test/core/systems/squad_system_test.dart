import 'dart:math' as math;

import 'package:drift_command/core/models/battle_state.dart';
import 'package:drift_command/core/models/ship_data.dart';
import 'package:drift_command/core/models/squad.dart';
import 'package:drift_command/core/systems/squad_system.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

BattleState _makeState({required List<ShipState> ships, required List<SquadState> squads}) {
  return BattleState(
    playerFactionId: 0,
    objectiveDescription: 'test',
    ships: {for (final s in ships) s.instanceId: s},
    squads: {for (final sq in squads) sq.squadId: sq},
    playerFlagshipId: ships.first.instanceId,
  );
}

ShipState _makeShip(String id, String squadId, Vector2 pos) => ShipState(
      instanceId: id,
      dataId: 'flagship',
      factionId: 0,
      position: pos,
      heading: 0,
      durability: 200,
      squadId: squadId,
    );

void main() {
  final system = SquadSystem();

  test('centroid follows leader position after update', () {
    final leader = _makeShip('sq_ship_0', 'sq', Vector2(100, 200));
    final follower = _makeShip('sq_ship_1', 'sq', Vector2(50, 50));
    final squad = SquadState(
      squadId: 'sq',
      type: SquadType.lineDivision,
      factionId: 0,
      centroid: Vector2.zero(),
      heading: 0,
      shipInstanceIds: ['sq_ship_0', 'sq_ship_1'],
    );
    final state = _makeState(ships: [leader, follower], squads: [squad]);

    system.update(state);

    expect(squad.centroid.x, closeTo(100, 0.01));
    expect(squad.centroid.y, closeTo(200, 0.01));
  });

  test('follower ship gets moveTo order with rotated offset', () {
    final leader = _makeShip('sq_ship_0', 'sq', Vector2(500, 300));
    final follower = _makeShip('sq_ship_1', 'sq', Vector2(400, 300));
    final squad = SquadState(
      squadId: 'sq',
      type: SquadType.lineDivision,
      factionId: 0,
      centroid: Vector2(500, 300),
      heading: 0, // heading 0: offset (-20,0) stays at x-20, y+0
      shipInstanceIds: ['sq_ship_0', 'sq_ship_1'],
    );
    final state = _makeState(ships: [leader, follower], squads: [squad]);

    system.update(state);

    final order = follower.activeOrder;
    expect(order, isNotNull);
    expect(order!.type, OrderType.moveTo);
    // lineDivision offset[1] = Vector2(20, 0); with heading=0: rx=20, ry=0
    expect(order.targetPosition!.x, closeTo(500 + 20, 0.1));
    expect(order.targetPosition!.y, closeTo(300, 0.1));
  });

  test('dead leader triggers re-election — second ship becomes effective leader', () {
    final leader = _makeShip('sq_ship_0', 'sq', Vector2(100, 100));
    final follower = _makeShip('sq_ship_1', 'sq', Vector2(200, 200));
    leader.isAlive = false; // kill leader

    final squad = SquadState(
      squadId: 'sq',
      type: SquadType.lineDivision,
      factionId: 0,
      centroid: Vector2.zero(),
      heading: 0,
      shipInstanceIds: ['sq_ship_0', 'sq_ship_1'],
    );
    final squadOrder = Order(type: OrderType.moveTo, targetPosition: Vector2(999, 999));
    squad.activeOrder = squadOrder;

    final state = _makeState(ships: [leader, follower], squads: [squad]);

    system.update(state);

    // Centroid should now track the follower (new effective leader)
    expect(squad.centroid.x, closeTo(200, 0.01));
    expect(squad.centroid.y, closeTo(200, 0.01));
    // The now-leader should receive the squad order
    expect(follower.activeOrder?.type, OrderType.moveTo);
  });

  test('squad order propagates to leader via squad activeOrder', () {
    final leader = _makeShip('sq_ship_0', 'sq', Vector2(100, 100));
    final squad = SquadState(
      squadId: 'sq',
      type: SquadType.flagship,
      factionId: 0,
      centroid: Vector2(100, 100),
      heading: 0,
      shipInstanceIds: ['sq_ship_0'],
    );
    final moveOrder = Order(type: OrderType.moveTo, targetPosition: Vector2(800, 600));
    squad.activeOrder = moveOrder;

    final state = _makeState(ships: [leader], squads: [squad]);

    system.update(state);

    expect(leader.activeOrder?.type, OrderType.moveTo);
    expect(leader.activeOrder?.targetPosition?.x, closeTo(800, 0.01));
  });

  test('formation offset rotates with heading', () {
    final leader = _makeShip('sq_ship_0', 'sq', Vector2(500, 300));
    final follower = _makeShip('sq_ship_1', 'sq', Vector2(400, 300));
    final heading = math.pi / 2; // 90 degrees: offset(20,0) → (0, 20)
    final squad = SquadState(
      squadId: 'sq',
      type: SquadType.lineDivision,
      factionId: 0,
      centroid: Vector2(500, 300),
      heading: heading,
      shipInstanceIds: ['sq_ship_0', 'sq_ship_1'],
    );
    leader.heading = heading;
    final state = _makeState(ships: [leader, follower], squads: [squad]);

    system.update(state);

    // offset[1] = (20, 0); rotated 90°: rx = 20*cos(90)-0*sin(90) = 0; ry = 20*sin(90)+0*cos(90) = 20
    final order = follower.activeOrder!;
    expect(order.targetPosition!.x, closeTo(500, 0.5));
    expect(order.targetPosition!.y, closeTo(320, 0.5));
  });
}
