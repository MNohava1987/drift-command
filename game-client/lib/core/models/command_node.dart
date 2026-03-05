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
