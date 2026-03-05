import 'package:drift_command/core/models/ship_data.dart';
import 'package:drift_command/core/systems/kinematic_system.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Map<String, ShipData> registry;

  setUp(() {
    registry = {
      'heavy_line': const ShipData(
        id: 'heavy_line',
        displayName: 'Heavy Line Ship',
        role: ShipRole.heavyLine,
        massClass: MassClass.heavy,
        maxAcceleration: 8.0,
        turnRate: 0.15,
        commandLatencyMod: 1.5,
        sensorRange: 200.0,
        weaponRange: 150.0,
        maxDurability: 100.0,
        roleTags: [RoleTag.directFire],
      ),
      'fast_raider': const ShipData(
        id: 'fast_raider',
        displayName: 'Fast Raider',
        role: ShipRole.fastRaider,
        massClass: MassClass.light,
        maxAcceleration: 25.0,
        turnRate: 1.2,
        commandLatencyMod: 0.8,
        sensorRange: 250.0,
        weaponRange: 100.0,
        maxDurability: 40.0,
        roleTags: [RoleTag.directFire, RoleTag.flanking],
      ),
    };
  });

  test('dead ships are not updated', () {
    final system = KinematicSystem(shipDataRegistry: registry);
    final ship = ShipState(
      instanceId: 'ship1',
      dataId: 'heavy_line',
      factionId: 0,
      position: Vector2(0, 0),
      heading: 0,
      durability: 0,
    )..isAlive = false;

    system.update([ship], 1.0);

    expect(ship.position, Vector2(0, 0));
    expect(ship.velocity, Vector2.zero());
  });

  test('ship with no orders maintains velocity (coasts)', () {
    final system = KinematicSystem(shipDataRegistry: registry);
    final ship = ShipState(
      instanceId: 'ship1',
      dataId: 'heavy_line',
      factionId: 0,
      position: Vector2(0, 0),
      heading: 0,
      durability: 100,
    )..velocity = Vector2(10, 0);

    system.update([ship], 1.0);

    // With no orders the ship coasts (no deceleration triggered),
    // position moves by velocity * dt
    expect(ship.position.x, greaterThan(0));
  });

  test('heavy ship max speed is lower than light ship max speed', () {
    final system = KinematicSystem(shipDataRegistry: registry);

    final heavy = ShipState(
      instanceId: 'heavy',
      dataId: 'heavy_line',
      factionId: 0,
      position: Vector2(0, 0),
      heading: 0,
      durability: 100,
    );

    final light = ShipState(
      instanceId: 'light',
      dataId: 'fast_raider',
      factionId: 0,
      position: Vector2(0, 0),
      heading: 0,
      durability: 40,
    );

    // Run for 10 seconds with no orders (coasting at zero velocity both start at)
    // Add a move order with a far target and let them accelerate
    final target = Vector2(10000, 0);
    heavy.pendingOrders.add(Order(
      type: OrderType.moveTo,
      issuedAt: 0,
      arrivesAt: 0,
      targetPosition: target,
    ));
    light.pendingOrders.add(Order(
      type: OrderType.moveTo,
      issuedAt: 0,
      arrivesAt: 0,
      targetPosition: target,
    ));

    for (int i = 0; i < 100; i++) {
      system.update([heavy, light], 0.1);
    }

    expect(light.velocity.length, greaterThan(heavy.velocity.length));
  });
}
