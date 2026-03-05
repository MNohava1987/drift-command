import 'dart:convert';

import 'package:drift_command/core/models/battle_state.dart';
import 'package:drift_command/core/models/command_node.dart';
import 'package:drift_command/core/services/scenario_loader.dart';
import 'package:drift_command/data/ships/ship_definitions.dart';
import 'package:flutter_test/flutter_test.dart';

// Inline copy of scenario_001.json — no asset loading needed in unit tests.
const _scenarioJson = '''
{
  "id": "scenario_001",
  "name": "First Contact",
  "objective": "Destroy the enemy flagship",
  "playerFactionId": 0,
  "winCondition": {
    "type": "destroyEnemyFlagship",
    "targetShipId": "e_flagship"
  },
  "ships": [
    {
      "instanceId": "p_flagship", "dataId": "flagship", "factionId": 0,
      "position": [150, 300], "heading": 0,
      "commandNodeId": "pf_node", "commandNodeType": "flagship"
    },
    {
      "instanceId": "p_relay", "dataId": "command_relay", "factionId": 0,
      "position": [220, 240], "heading": 0,
      "commandNodeId": "pr_node", "commandNodeType": "relay",
      "parentNodeId": "pf_node"
    },
    {
      "instanceId": "p_heavy", "dataId": "heavy_line", "factionId": 0,
      "position": [170, 360], "heading": 0,
      "assignedCommandNodeId": "pr_node"
    },
    {
      "instanceId": "p_escort", "dataId": "light_escort", "factionId": 0,
      "position": [200, 220], "heading": 0,
      "assignedCommandNodeId": "pr_node"
    },
    {
      "instanceId": "e_flagship", "dataId": "flagship", "factionId": 1,
      "position": [850, 300], "heading": 3.14159,
      "commandNodeId": "ef_node", "commandNodeType": "flagship"
    },
    {
      "instanceId": "e_relay", "dataId": "command_relay", "factionId": 1,
      "position": [780, 360], "heading": 3.14159,
      "commandNodeId": "er_node", "commandNodeType": "relay",
      "parentNodeId": "ef_node"
    },
    {
      "instanceId": "e_heavy", "dataId": "heavy_line", "factionId": 1,
      "position": [830, 240], "heading": 3.14159,
      "assignedCommandNodeId": "er_node"
    },
    {
      "instanceId": "e_raider", "dataId": "fast_raider", "factionId": 1,
      "position": [760, 290], "heading": 3.14159,
      "assignedCommandNodeId": "er_node"
    }
  ]
}
''';

void main() {
  late BattleState state;

  setUpAll(() {
    final json = jsonDecode(_scenarioJson) as Map<String, dynamic>;
    state = ScenarioLoader.fromJson(json, kShipDefinitions);
  });

  test('correct total ship count', () {
    expect(state.ships.length, 8);
  });

  test('player ships are faction 0', () {
    expect(state.playerShips.length, 4);
    expect(state.playerShips.every((s) => s.factionId == 0), isTrue);
  });

  test('enemy ships are faction 1', () {
    expect(state.enemyShips.length, 4);
    expect(state.enemyShips.every((s) => s.factionId == 1), isTrue);
  });

  test('command topology built for both factions', () {
    expect(state.topologies.containsKey(0), isTrue);
    expect(state.topologies.containsKey(1), isTrue);
  });

  test('player topology has flagship and relay nodes', () {
    final topo = state.topologies[0]!;
    expect(topo.nodes.length, 2);
    final flagship = topo.nodes[topo.flagshipNodeId]!;
    expect(flagship.type, CommandNodeType.flagship);
    expect(flagship.childNodeIds.length, 1);
  });

  test('relay node has two assigned combat ships', () {
    final topo = state.topologies[0]!;
    final relayNodeId = topo.flagship.childNodeIds.first;
    final relay = topo.nodes[relayNodeId]!;
    expect(relay.assignedCombatShipIds.length, 2);
    expect(relay.assignedCombatShipIds, containsAll(['p_heavy', 'p_escort']));
  });

  test('durability set from ShipData.maxDurability', () {
    final flagship = state.ships['p_flagship']!;
    final flagshipData = kShipDefinitions['flagship']!;
    expect(flagship.durability, flagshipData.maxDurability);

    final raider = state.ships['e_raider']!;
    final raiderData = kShipDefinitions['fast_raider']!;
    expect(raider.durability, raiderData.maxDurability);
  });

  test('combat ships have assignedCommandNodeId set', () {
    expect(state.ships['p_heavy']!.assignedCommandNodeId, 'pr_node');
    expect(state.ships['p_escort']!.assignedCommandNodeId, 'pr_node');
    expect(state.ships['e_heavy']!.assignedCommandNodeId, 'er_node');
    expect(state.ships['e_raider']!.assignedCommandNodeId, 'er_node');
  });

  test('win condition is destroyEnemyFlagship targeting e_flagship', () {
    final wc = state.winCondition!;
    expect(wc.type, WinConditionType.destroyEnemyFlagship);
    expect(wc.targetShipId, 'e_flagship');
  });
}
