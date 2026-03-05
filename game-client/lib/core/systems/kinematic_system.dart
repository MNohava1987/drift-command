import 'dart:math' as math;
import 'package:flame/components.dart';
import '../models/ship_data.dart';

/// Handles all ship movement: applying thrust, turning commitment,
/// and position integration.
///
/// This is pure Dart — no Flame or Flutter dependency. Fully unit-testable.
class KinematicSystem {
  final Map<String, ShipData> shipDataRegistry;

  KinematicSystem({required this.shipDataRegistry});

  /// Update all ship positions for one simulation step.
  ///
  /// [battleTime] is the current battle clock (used to promote pending orders).
  /// [allShips] is the full ship map (used for attackTarget tracking).
  void update(
    List<ShipState> ships,
    double dt, {
    double battleTime = 0.0,
    Map<String, ShipState> allShips = const {},
  }) {
    for (final ship in ships) {
      if (!ship.isAlive) continue;
      final data = shipDataRegistry[ship.dataId];
      if (data == null) continue;
      _promoteReadyOrders(ship, battleTime);
      _executeActiveOrder(ship, data, dt, allShips);
      _integratePosition(ship, dt);
    }
  }

  /// Moves the first arrived pending order into [ship.activeOrder].
  void _promoteReadyOrders(ShipState ship, double battleTime) {
    if (ship.activeOrder != null) return;
    final idx = ship.pendingOrders.indexWhere((o) => o.isReady(battleTime));
    if (idx >= 0) {
      ship.activeOrder = ship.pendingOrders[idx];
      ship.pendingOrders.removeAt(idx);
    }
  }

  /// Applies the currently active order to the ship for one tick.
  void _executeActiveOrder(
    ShipState ship,
    ShipData data,
    double dt,
    Map<String, ShipState> allShips,
  ) {
    final order = ship.activeOrder;
    if (order == null) return;

    switch (order.type) {
      case OrderType.moveTo:
        if (order.targetPosition != null) {
          final dist = ship.position.distanceTo(order.targetPosition!);
          if (dist < 10.0) {
            ship.activeOrder = null;
            return;
          }
          _steerToward(ship, data, order.targetPosition!, dt);
        }
      case OrderType.attackTarget:
        final targetPos = (order.targetShipId != null
                ? allShips[order.targetShipId]?.position
                : null) ??
            order.targetPosition;
        if (targetPos != null) {
          _steerToward(ship, data, targetPos, dt);
        }
      case OrderType.hold:
        _decelerate(ship, data, dt);
      case OrderType.retreat:
        if (order.targetPosition != null) {
          final dist = ship.position.distanceTo(order.targetPosition!);
          if (dist < 10.0) {
            ship.activeOrder = null;
            return;
          }
          _steerToward(ship, data, order.targetPosition!, dt);
        } else {
          _decelerate(ship, data, dt);
        }
      default:
        break;
    }
  }

  void _steerToward(
      ShipState ship, ShipData data, Vector2 target, double dt) {
    final toTarget = target - ship.position;
    if (toTarget.length < 1.0) return;

    final desiredHeading = math.atan2(toTarget.y, toTarget.x);
    final headingDelta = _normalizeAngle(desiredHeading - ship.heading);

    final maxTurn = data.turnRate * dt;
    if (headingDelta.abs() > maxTurn) {
      ship.heading += maxTurn * headingDelta.sign;
    } else {
      ship.heading = desiredHeading;
    }

    final thrustDir = Vector2(
      math.cos(ship.heading),
      math.sin(ship.heading),
    );

    ship.velocity += thrustDir * data.maxAcceleration * dt;

    final maxSpeed = _maxSpeedForClass(data.massClass);
    if (ship.velocity.length > maxSpeed) {
      ship.velocity = ship.velocity.normalized() * maxSpeed;
    }
  }

  void _decelerate(ShipState ship, ShipData data, double dt) {
    final decelRate = data.maxAcceleration * 0.5 * dt;
    if (ship.velocity.length <= decelRate) {
      ship.velocity = Vector2.zero();
    } else {
      ship.velocity -= ship.velocity.normalized() * decelRate;
    }
  }

  void _integratePosition(ShipState ship, double dt) {
    ship.position += ship.velocity * dt;
  }

  double _normalizeAngle(double angle) {
    while (angle > math.pi) {
      angle -= 2 * math.pi;
    }
    while (angle < -math.pi) {
      angle += 2 * math.pi;
    }
    return angle;
  }

  double _maxSpeedForClass(MassClass massClass) {
    return switch (massClass) {
      MassClass.light => 120.0,
      MassClass.medium => 80.0,
      MassClass.heavy => 50.0,
      MassClass.capital => 30.0,
    };
  }
}
