import 'package:flame/components.dart';
import '../models/ship_data.dart';
import '../models/battle_state.dart';

/// Handles order issuance. Orders are applied immediately — no propagation
/// delay, no topology lookup, no command window gate.
///
/// The player is the Captain. Their ships hear them directly.
class CommandSystem {
  /// Issue an order to a single ship. The order takes effect immediately.
  void issueOrder({
    required BattleState state,
    required String targetShipId,
    required OrderType orderType,
    Vector2? targetPosition,
    String? targetEnemyId,
    double targetSpeedFraction = 0.5,
  }) {
    final target = state.ships[targetShipId];
    if (target == null || !target.isAlive) return;

    target.activeOrder = Order(
      type: orderType,
      targetPosition: targetPosition,
      targetShipId: targetEnemyId,
      targetSpeedFraction: targetSpeedFraction,
    );
    // Flash ring to confirm order received
    target.orderFlashUntil = state.battleTime + 0.45;
  }

  /// Issue the same order to every alive player ship.
  void issueFleetOrder({
    required BattleState state,
    required OrderType orderType,
    Vector2? targetPosition,
    String? targetEnemyId,
    double targetSpeedFraction = 0.5,
  }) {
    for (final ship in state.playerShips) {
      if (!ship.isAlive) continue;
      issueOrder(
        state: state,
        targetShipId: ship.instanceId,
        orderType: orderType,
        targetPosition: targetPosition,
        targetEnemyId: targetEnemyId,
        targetSpeedFraction: targetSpeedFraction,
      );
    }
  }
}
