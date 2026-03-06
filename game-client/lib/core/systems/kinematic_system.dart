import 'dart:math' as math;
import 'package:flame/components.dart';
import '../models/ship_data.dart';

/// Handles all ship movement with true Newtonian momentum.
///
/// Ships have a velocity vector that persists between ticks. Thrust changes
/// the vector gradually. Ships must begin braking early or they overshoot.
/// Heavier ships change direction more slowly — speed is a commitment.
///
/// This is pure Dart — no Flame or Flutter dependency. Fully unit-testable.
class KinematicSystem {
  final Map<String, ShipData> shipDataRegistry;

  KinematicSystem({required this.shipDataRegistry});

  void update(
    List<ShipState> ships,
    double dt, {
    Map<String, ShipState> allShips = const {},
  }) {
    for (final ship in ships) {
      if (!ship.isAlive) continue;
      final data = shipDataRegistry[ship.dataId];
      if (data == null) continue;
      _executeActiveOrder(ship, data, dt, allShips);
      ship.position += ship.velocity * dt;
    }
  }

  void _executeActiveOrder(
    ShipState ship,
    ShipData data,
    double dt,
    Map<String, ShipState> allShips,
  ) {
    final order = ship.activeOrder;
    if (order == null) {
      // No active order — ship brakes to a stop.
      _applyBraking(ship, data, dt);
      return;
    }

    switch (order.type) {
      case OrderType.moveTo:
        final target = order.targetPosition;
        if (target == null) return;
        final arrived = _navigateTo(
          ship, data, target, dt, order.targetSpeedFraction,
          stopAtTarget: true,
        );
        if (arrived) ship.activeOrder = null;

      case OrderType.attackTarget:
        final enemy = order.targetShipId != null
            ? allShips[order.targetShipId]
            : null;

        if (enemy != null && !enemy.isAlive) {
          ship.activeOrder = null;
          return;
        }

        final enemyPos =
            (enemy != null && enemy.isAlive) ? enemy.position : order.targetPosition;
        if (enemyPos == null) return;

        final weaponRange = data.weaponRange;
        final toEnemy = enemyPos - ship.position;
        final distance = toEnemy.length;
        if (distance < weaponRange * 0.85) {
          _applyBraking(ship, data, dt);
        } else {
          final engagePos =
              enemyPos - toEnemy.normalized() * (weaponRange * 0.80);
          _navigateTo(
            ship, data, engagePos, dt, order.targetSpeedFraction,
            stopAtTarget: true,
          );
        }

      case OrderType.hold:
        _applyBraking(ship, data, dt);

      case OrderType.retreat:
        final target = order.targetPosition;
        if (target == null) {
          _applyBraking(ship, data, dt);
          return;
        }
        final arrived = _navigateTo(
          ship, data, target, dt, order.targetSpeedFraction,
          stopAtTarget: true,
        );
        if (arrived) ship.activeOrder = null;
    }
  }

  /// Navigate toward [target]. Returns true when the ship has stopped at target.
  bool _navigateTo(
    ShipState ship,
    ShipData data,
    Vector2 target,
    double dt,
    double speedFraction, {
    required bool stopAtTarget,
  }) {
    final toTarget = target - ship.position;
    final distance = toTarget.length;
    final maxSpeed = _maxSpeedForClass(data.massClass) * speedFraction.clamp(0.1, 1.0);
    final currentSpeed = ship.velocity.length;

    if ((distance < 5.0 && currentSpeed < 20.0) ||
        (distance < 20.0 && currentSpeed < 10.0)) {
      ship.velocity = Vector2.zero();
      return true;
    }

    if (stopAtTarget) {
      final stoppingDist =
          (currentSpeed * currentSpeed) / (2 * data.maxAcceleration + 0.001);
      if (distance <= stoppingDist * 1.3) {
        _applyBraking(ship, data, dt);
        return false;
      }
      final safeApproachSpeed =
          math.sqrt(2.0 * data.maxAcceleration * distance * 0.5 + 0.01);
      _steerToward(ship, data, target, dt, math.min(maxSpeed, safeApproachSpeed));
      return false;
    }

    _steerToward(ship, data, target, dt, maxSpeed);
    return false;
  }

  void _steerToward(
    ShipState ship,
    ShipData data,
    Vector2 target,
    double dt,
    double maxSpeed,
  ) {
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

    final thrustDir = Vector2(math.cos(ship.heading), math.sin(ship.heading));
    ship.velocity += thrustDir * data.maxAcceleration * dt;
    ship.thrustVector = thrustDir;

    if (ship.velocity.length > maxSpeed) {
      ship.velocity = ship.velocity.normalized() * maxSpeed;
    }
  }

  void _applyBraking(ShipState ship, ShipData data, double dt) {
    final speed = ship.velocity.length;

    if (speed > 2.0) {
      final retrograde = math.atan2(-ship.velocity.y, -ship.velocity.x);
      final delta = _normalizeAngle(retrograde - ship.heading);
      final maxTurn = data.turnRate * dt;
      ship.heading += delta.abs() > maxTurn ? maxTurn * delta.sign : delta;
      ship.thrustVector = Vector2(math.cos(ship.heading), math.sin(ship.heading));
    } else {
      ship.thrustVector = Vector2.zero();
    }

    final brakeForce = data.maxAcceleration * dt;
    if (speed <= brakeForce) {
      ship.velocity = Vector2.zero();
    } else {
      ship.velocity -= ship.velocity.normalized() * brakeForce;
    }
  }

  double _normalizeAngle(double angle) {
    while (angle > math.pi) { angle -= 2 * math.pi; }
    while (angle < -math.pi) { angle += 2 * math.pi; }
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
