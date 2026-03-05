import 'package:flame/components.dart';
import '../models/ship_data.dart';
import '../models/command_node.dart';
import '../models/battle_state.dart';

/// Base propagation speed in units/second.
/// An order covering 100 units of distance takes 5 seconds to arrive
/// at base speed (100 / 20 = 5).
const double kBasePropagationSpeed = 20.0;

/// Handles order issuance, propagation delay calculation,
/// and command topology maintenance.
class CommandSystem {
  /// Issue an order from the flagship toward [targetShipId].
  /// Calculates propagation delay through the command chain and
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
      flagship: flagship,
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

    // Cap the queue at 3 pending orders; drop the oldest to preserve the newest intent.
    if (target.pendingOrders.length >= 3) {
      target.pendingOrders.removeAt(0);
    }
    target.pendingOrders.add(order);
  }

  double _calculatePropagationDelay({
    required ShipState flagship,
    required ShipState target,
    required CommandTopology topology,
    required Map<String, ShipState> ships,
    required Map<String, ShipData> registry,
  }) {
    final assignedNodeId = target.assignedCommandNodeId;

    if (assignedNodeId == null) {
      // Direct order from flagship — full distance
      final dist = flagship.position.distanceTo(target.position);
      final targetData = registry[target.dataId];
      final latencyMod = targetData?.commandLatencyMod ?? 1.0;
      return (dist / kBasePropagationSpeed) * latencyMod;
    }

    final relayNode = topology.nodes[assignedNodeId];
    if (relayNode == null) {
      final dist = flagship.position.distanceTo(target.position);
      return dist / kBasePropagationSpeed;
    }

    final targetData = registry[target.dataId];
    final latencyMod = targetData?.commandLatencyMod ?? 1.0;
    final directDist = flagship.position.distanceTo(target.position);
    final directDelay = (directDist / kBasePropagationSpeed) * latencyMod;

    final relay = ships[relayNode.shipInstanceId];
    if (relay == null || !relay.isAlive) {
      // Relay dead — check connectivity, fall back to direct
      final connected = topology.isConnected(
        target.instanceId,
        {for (final s in ships.values) s.instanceId: s.isAlive},
        assignedCommandNodeId: target.assignedCommandNodeId,
      );
      if (!connected) return double.infinity;
      return directDelay;
    }

    // Compare direct vs relay path — use whichever is shorter.
    // Ships close to the flagship skip the relay entirely.
    final flagToRelay = flagship.position.distanceTo(relay.position);
    final relayToTarget = relay.position.distanceTo(target.position);
    final relayDelay = ((flagToRelay + relayToTarget) / kBasePropagationSpeed) * latencyMod;

    return directDelay < relayDelay ? directDelay : relayDelay;
  }

  /// Remove pending orders from disconnected ships and apply their doctrine.
  void applyDisconnectedDoctrine(BattleState state) {
    for (final faction in state.topologies.values) {
      final aliveMap = state.aliveMap;

      for (final ship in state.ships.values) {
        if (!ship.isAlive) continue;
        if (ship.factionId != faction.factionId) continue;

        final connected = faction.isConnected(
          ship.instanceId,
          aliveMap,
          assignedCommandNodeId: ship.assignedCommandNodeId,
        );
        if (!connected &&
            (ship.pendingOrders.isNotEmpty || ship.activeOrder != null)) {
          ship.pendingOrders.clear();
          ship.activeOrder = null;
          // doctrine holds, ship will behave per activeDoctrine
        }
      }
    }
  }
}
