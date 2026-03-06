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

  test('ship with no active order brakes to a stop (auto-hold)', () {
    final system = KinematicSystem(shipDataRegistry: registry);
    final ship = ShipState(
      instanceId: 'ship1',
      dataId: 'heavy_line',
      factionId: 0,
      position: Vector2(0, 0),
      heading: 0,
      durability: 100,
    )..velocity = Vector2(10, 0);

    // Ship moved in the braking direction (forward), but braking reduced speed
    system.update([ship], 1.0);
    expect(ship.position.x, greaterThan(0));
    expect(ship.velocity.length, lessThan(10.0)); // speed reduced by braking
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

    final target = Vector2(10000, 0);
    heavy.activeOrder = Order(type: OrderType.moveTo, targetPosition: target);
    light.activeOrder = Order(type: OrderType.moveTo, targetPosition: target);

    for (int i = 0; i < 100; i++) {
      system.update([heavy, light], 0.1);
    }

    expect(light.velocity.length, greaterThan(heavy.velocity.length));
  });
}
