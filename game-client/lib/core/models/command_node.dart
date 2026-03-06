import 'ship_data.dart';

/// Range within which a ship has direct comms with the flagship (no relay needed).
const double kDirectCommsRange = 500.0;

/// Range within which a relay ship can bridge comms to a combat ship.
const double kRelayCommsRange = 800.0;

/// A node in the command hierarchy.
/// Flagship is the root; command relay ships are intermediate nodes;
/// combat ships are leaves.
class CommandNode {
  final String nodeId;
  final String shipInstanceId;
  final CommandNodeType type;

  String? parentNodeId;                  // null for flagship (root)
  List<String> childNodeIds;             // relay or combat ships reporting to this node
  List<String> assignedCombatShipIds;    // leaf ships receiving orders via this node

  CommandNode({
    required this.nodeId,
    required this.shipInstanceId,
    required this.type,
    this.parentNodeId,
    List<String>? childNodeIds,
    List<String>? assignedCombatShipIds,
  })  : childNodeIds = childNodeIds ?? [],
        assignedCombatShipIds = assignedCombatShipIds ?? [];

  bool get isRoot => type == CommandNodeType.flagship;
  bool get isRelay => type == CommandNodeType.relay;
}

enum CommandNodeType {
  flagship,
  relay,
}

/// The full command topology for one faction in a battle.
class CommandTopology {
  final int factionId;
  final String flagshipNodeId;
  final Map<String, CommandNode> nodes;  // keyed by nodeId

  CommandTopology({
    required this.factionId,
    required this.flagshipNodeId,
    required this.nodes,
  });

  CommandNode get flagship => nodes[flagshipNodeId]!;

  /// Returns the connectivity tier for a ship:
  /// - 2 = direct comms (within kDirectCommsRange of flagship)
  /// - 1 = relay comms (relay within kDirectCommsRange of flagship AND relay within kRelayCommsRange of ship)
  /// - 0 = isolated (no path to flagship)
  int connectivityTier(ShipState ship, Map<String, ShipState> ships) {
    final flagshipShip = ships[flagship.shipInstanceId];
    if (flagshipShip == null || !flagshipShip.isAlive) return 0;
    // Flagship itself is always tier 2
    if (ship.instanceId == flagshipShip.instanceId) return 2;
    if (!ship.isAlive) return 0;

    final directDist = flagshipShip.position.distanceTo(ship.position);
    if (directDist <= kDirectCommsRange) return 2;

    // Check relay paths
    for (final node in nodes.values) {
      if (node.isRoot) continue;
      final relay = ships[node.shipInstanceId];
      if (relay == null || !relay.isAlive) continue;
      final flagToRelay = flagshipShip.position.distanceTo(relay.position);
      final relayToShip = relay.position.distanceTo(ship.position);
      if (flagToRelay <= kDirectCommsRange && relayToShip <= kRelayCommsRange) return 1;
    }

    return 0;
  }

  /// Legacy connectivity check — preserved for existing tests.
  /// Walks the command topology tree to determine if a ship has an unbroken
  /// path to the flagship.
  bool isConnected(
    String shipInstanceId,
    Map<String, bool> aliveShips, {
    String? assignedCommandNodeId,
  }) {
    // Walk from the ship's node up to the flagship.
    // If any node along the path is destroyed, the ship is disconnected.
    for (final node in nodes.values) {
      if (node.shipInstanceId == shipInstanceId) {
        return _pathToRootAlive(node, aliveShips);
      }
    }
    // Leaf combat ships are not command nodes themselves — check via their
    // assigned command node (flagship or relay they report to).
    if (assignedCommandNodeId != null) {
      final assignedNode = nodes[assignedCommandNodeId];
      if (assignedNode == null) return false;
      return _pathToRootAlive(assignedNode, aliveShips);
    }
    return false;
  }

  bool _pathToRootAlive(CommandNode node, Map<String, bool> aliveShips) {
    if (!aliveShips[node.shipInstanceId]!) return false;
    if (node.isRoot) return true;
    final parent = nodes[node.parentNodeId];
    if (parent == null) return false;
    return _pathToRootAlive(parent, aliveShips);
  }
}
