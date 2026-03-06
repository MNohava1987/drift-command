import 'package:flame/components.dart';
import '../models/ship_data.dart';
import '../models/command_node.dart';
import '../models/battle_state.dart';

/// Comms delay when a ship has direct line-of-sight to flagship (tier 2).
const double kDirectCommsDelay = 1.0;

/// Comms delay when a relay ship is bridging the connection (tier 1).
const double kRelayCommsDelay = 3.0;

/// Comms delay when a ship is isolated — no usable path to flagship (tier 0).
const double kIsolatedDelay = 10.0;

/// Handles order issuance, propagation delay calculation,
/// and command topology maintenance.
class CommandSystem {
  /// Issue an order from the flagship toward [targetShipId].
  /// Calculates propagation delay based on connectivity tier and
  /// creates time-delayed Order objects on the target ship.
  void issueOrder({
    required BattleState state,
    required String targetShipId,
    required OrderType orderType,
    Vector2? targetPosition,
    String? targetEnemyId,
    required Map<String, ShipData> registry,
    double targetSpeedFraction = 0.5,
  }) {
    final target = state.ships[targetShipId];
    if (target == null || !target.isAlive) return;

    final topology = state.topologies[target.factionId];
    if (topology == null) return;

    final flagship = state.ships[topology.flagship.shipInstanceId];
    if (flagship == null || !flagship.isAlive) return;

    final delay = _calculatePropagationDelay(
      target: target,
      topology: topology,
      ships: state.ships,
      registry: registry,
    );

    final order = Order(
      type: orderType,
      issuedAt: state.battleTime,
      arrivesAt: state.battleTime + delay,
      targetPosition: targetPosition,
      targetShipId: targetEnemyId,
      targetSpeedFraction: targetSpeedFraction,
    );

    // Cap the queue at 6 pending orders; drop the oldest to preserve the newest intent.
    if (target.pendingOrders.length >= 6) {
      target.pendingOrders.removeAt(0);
    }
    target.pendingOrders.add(order);
  }

  double _calculatePropagationDelay({
    required ShipState target,
    required CommandTopology topology,
    required Map<String, ShipState> ships,
    required Map<String, ShipData> registry,
  }) {
    final tier = topology.connectivityTier(target, ships);
    final targetData = registry[target.dataId];
    final latencyMod = targetData?.commandLatencyMod ?? 1.0;

    switch (tier) {
      case 2:
        return kDirectCommsDelay * latencyMod;
      case 1:
        return kRelayCommsDelay * latencyMod;
      default:
        return kIsolatedDelay; // isolated ships get no latency mod benefit
    }
  }

  /// Remove pending orders from disconnected ships and apply their doctrine.
  void applyDisconnectedDoctrine(BattleState state) {
    for (final faction in state.topologies.values) {
      for (final ship in state.ships.values) {
        if (!ship.isAlive) continue;
        if (ship.factionId != faction.factionId) continue;

        final tier = faction.connectivityTier(ship, state.ships);
        if (tier == 0 &&
            (ship.pendingOrders.isNotEmpty || ship.activeOrder != null)) {
          ship.pendingOrders.clear();
          ship.activeOrder = null;
          // doctrine holds, ship will behave per activeDoctrine
        }
      }
    }
  }
}
