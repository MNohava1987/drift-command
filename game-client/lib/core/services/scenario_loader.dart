import 'package:flame/components.dart';
import '../models/ship_data.dart';
import '../models/command_node.dart';
import '../models/battle_state.dart';

/// Parses a scenario JSON map into a ready-to-run [BattleState].
///
/// Expected JSON shape — see assets/scenarios/scenario_001.json for a full example.
class ScenarioLoader {
  /// Build a [BattleState] from a decoded JSON map and the ship data registry.
  ///
  /// Ships that have [commandNodeId]/[commandNodeType] fields become command
  /// nodes (flagship or relay). Ships with [assignedCommandNodeId] are
  /// combat/leaf ships that report through a relay.
  ///
  /// When [carryDamage] is true, [startingDurabilityFractions] (keyed by dataId)
  /// are applied to player ships.
  static BattleState fromJson(
    Map<String, dynamic> json,
    Map<String, ShipData> registry, {
    bool carryDamage = false,
    Map<String, double>? startingDurabilityFractions,
  }) {
    final playerFactionId = json['playerFactionId'] as int;
    final objective = json['objective'] as String;

    final shipsMap = <String, ShipState>{};
    final nodesMap = <String, CommandNode>{};
    final nodeToFaction = <String, int>{};

    // ── Pass 1: parse ships and create command nodes ──────────────────────
    for (final shipJson in json['ships'] as List<dynamic>) {
      final s = shipJson as Map<String, dynamic>;
      final instanceId = s['instanceId'] as String;
      final dataId = s['dataId'] as String;
      final factionId = s['factionId'] as int;
      final posRaw = s['position'] as List<dynamic>;
      final heading = (s['heading'] as num).toDouble();
      final data = registry[dataId];

        final maxDurability = data?.maxDurability ?? 100.0;
      double startDurability = maxDurability;
      if (carryDamage &&
          factionId == playerFactionId &&
          startingDurabilityFractions != null &&
          startingDurabilityFractions.containsKey(dataId)) {
        startDurability = maxDurability * startingDurabilityFractions[dataId]!.clamp(0.0, 1.0);
      }

      final ship = ShipState(
        instanceId: instanceId,
        dataId: dataId,
        factionId: factionId,
        position: Vector2(
          (posRaw[0] as num).toDouble(),
          (posRaw[1] as num).toDouble(),
        ),
        heading: heading,
        durability: startDurability,
      );

      // Flagship / relay ships create a command node
      if (s.containsKey('commandNodeId')) {
        final nodeId = s['commandNodeId'] as String;
        final nodeTypeStr = s['commandNodeType'] as String;
        final nodeType = nodeTypeStr == 'flagship'
            ? CommandNodeType.flagship
            : CommandNodeType.relay;
        final parentNodeId = s['parentNodeId'] as String?;

        nodesMap[nodeId] = CommandNode(
          nodeId: nodeId,
          shipInstanceId: instanceId,
          type: nodeType,
          parentNodeId: parentNodeId,
        );
        nodeToFaction[nodeId] = factionId;
      }

      // Combat ships have an assigned relay node
      if (s.containsKey('assignedCommandNodeId')) {
        ship.assignedCommandNodeId = s['assignedCommandNodeId'] as String;
      }

      shipsMap[instanceId] = ship;
    }

    // ── Pass 2: wire child node IDs and assigned combat ships ─────────────
    for (final node in nodesMap.values) {
      final parentId = node.parentNodeId;
      if (parentId != null && nodesMap.containsKey(parentId)) {
        nodesMap[parentId]!.childNodeIds.add(node.nodeId);
      }
    }

    for (final ship in shipsMap.values) {
      final assignedNodeId = ship.assignedCommandNodeId;
      if (assignedNodeId != null && nodesMap.containsKey(assignedNodeId)) {
        nodesMap[assignedNodeId]!.assignedCombatShipIds.add(ship.instanceId);
      }
    }

    // ── Pass 3: build topologies per faction ──────────────────────────────
    final topologies = <int, CommandTopology>{};

    // Group nodes by faction
    final nodesByFaction = <int, Map<String, CommandNode>>{};
    for (final entry in nodesMap.entries) {
      final faction = nodeToFaction[entry.key]!;
      nodesByFaction.putIfAbsent(faction, () => {})[entry.key] = entry.value;
    }

    for (final faction in nodesByFaction.keys) {
      final factionNodes = nodesByFaction[faction]!;
      final flagshipNodeId = factionNodes.values
          .firstWhere((n) => n.isRoot)
          .nodeId;
      topologies[faction] = CommandTopology(
        factionId: faction,
        flagshipNodeId: flagshipNodeId,
        nodes: factionNodes,
      );
    }

    // ── Win condition ─────────────────────────────────────────────────────
    WinCondition? winCondition;
    if (json.containsKey('winCondition')) {
      final wc = json['winCondition'] as Map<String, dynamic>;
      final typeStr = wc['type'] as String;
      WinConditionType wcType;
      switch (typeStr) {
        case 'destroyEnemyFlagship':
          wcType = WinConditionType.destroyEnemyFlagship;
        case 'destroyAllEnemies':
          wcType = WinConditionType.destroyAllEnemies;
        case 'surviveUntilTime':
          wcType = WinConditionType.surviveUntilTime;
        default:
          wcType = WinConditionType.custom;
      }
      winCondition = WinCondition(
        type: wcType,
        targetShipId: wc['targetShipId'] as String?,
        timeLimit: (wc['timeLimit'] as num?)?.toDouble(),
      );
    }

    // ── Faction postures ─────────────────────────────────────────────────────
    final factionPostures = <int, AiPosture>{};
    if (json.containsKey('factionPostures')) {
      final postureJson = json['factionPostures'] as Map<String, dynamic>;
      for (final entry in postureJson.entries) {
        final factionId = int.tryParse(entry.key);
        if (factionId != null) {
          factionPostures[factionId] = _parsePosture(entry.value as String);
        }
      }
    }

    return BattleState(
      playerFactionId: playerFactionId,
      objectiveDescription: objective,
      ships: shipsMap,
      topologies: topologies,
      winCondition: winCondition,
      factionPostures: factionPostures,
    );
  }

  static AiPosture _parsePosture(String value) => switch (value) {
        'aggressive' => AiPosture.aggressive,
        'defensive' => AiPosture.defensive,
        'flanking' => AiPosture.flanking,
        'holdAndFire' => AiPosture.holdAndFire,
        _ => AiPosture.aggressive,
      };
}
