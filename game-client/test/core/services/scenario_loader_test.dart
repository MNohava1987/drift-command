import 'dart:convert';

import 'package:drift_command/core/models/battle_state.dart';
import 'package:drift_command/core/services/scenario_loader.dart';
import 'package:drift_command/data/ships/ship_definitions.dart';
import 'package:flutter_test/flutter_test.dart';

// Inline copy of scenario_001.json (legacy fields like commandNodeId are
// silently ignored by the current loader).
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
      "position": [150, 300], "heading": 0
    },
    {
      "instanceId": "p_relay", "dataId": "command_relay", "factionId": 0,
      "position": [220, 240], "heading": 0
    },
    {
      "instanceId": "p_heavy", "dataId": "heavy_line", "factionId": 0,
      "position": [170, 360], "heading": 0
    },
    {
      "instanceId": "p_escort", "dataId": "light_escort", "factionId": 0,
      "position": [200, 220], "heading": 0
    },
    {
      "instanceId": "e_flagship", "dataId": "flagship", "factionId": 1,
      "position": [850, 300], "heading": 3.14159
    },
    {
      "instanceId": "e_relay", "dataId": "command_relay", "factionId": 1,
      "position": [780, 360], "heading": 3.14159
    },
    {
      "instanceId": "e_heavy", "dataId": "heavy_line", "factionId": 1,
      "position": [830, 240], "heading": 3.14159
    },
    {
      "instanceId": "e_raider", "dataId": "fast_raider", "factionId": 1,
      "position": [760, 290], "heading": 3.14159
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

  test('playerFlagshipId points to the player flagship', () {
    expect(state.playerFlagshipId, 'p_flagship');
    expect(state.playerFlagship?.dataId, 'flagship');
  });

  test('enemyFlagshipId points to the enemy flagship', () {
    expect(state.enemyFlagshipId, 'e_flagship');
    expect(state.enemyFlagship?.dataId, 'flagship');
  });

  test('durability set from ShipData.maxDurability', () {
    final flagship = state.ships['p_flagship']!;
    final flagshipData = kShipDefinitions['flagship']!;
    expect(flagship.durability, flagshipData.maxDurability);

    final raider = state.ships['e_raider']!;
    final raiderData = kShipDefinitions['fast_raider']!;
    expect(raider.durability, raiderData.maxDurability);
  });

  test('win condition is destroyEnemyFlagship targeting e_flagship', () {
    final wc = state.winCondition!;
    expect(wc.type, WinConditionType.destroyEnemyFlagship);
    expect(wc.targetShipId, 'e_flagship');
  });
}
