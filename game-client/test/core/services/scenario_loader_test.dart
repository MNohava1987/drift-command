import 'dart:convert';

import 'package:drift_command/core/models/battle_state.dart';
import 'package:drift_command/core/models/squad.dart';
import 'package:drift_command/core/services/scenario_loader.dart';
import 'package:drift_command/data/ships/ship_definitions.dart';
import 'package:flutter_test/flutter_test.dart';

// Phase 2 test: flagship squad + enemy raidPack + enemy flagship.
// 1 player ship + 1 enemy flagship ship + 6 raider ships = 8 total ships.
// 3 squads total (p_flagship, e_flagship, e_raid_1).
const _scenarioJson = '''
{
  "id": "test_scenario",
  "objective": "Destroy the enemy flagship",
  "playerFactionId": 0,
  "playerBudget": 8,
  "availableSquadTypes": ["lineDivision", "raidPack"],
  "winCondition": { "type": "destroyEnemyFlagship" },
  "factionPostures": { "1": "aggressive" },
  "playerSquads": [
    { "squadId": "p_flagship", "type": "flagship", "position": [200, 600], "heading": 0 }
  ],
  "enemySquads": [
    { "squadId": "e_flagship", "type": "flagship", "factionId": 1, "position": [1800, 600], "heading": 3.14159, "engagementMode": "engage" },
    { "squadId": "e_raid_1", "type": "raidPack", "factionId": 1, "position": [1600, 600], "heading": 3.14159, "engagementMode": "engage" }
  ]
}
''';

void main() {
  late BattleState state;

  setUpAll(() {
    final json = jsonDecode(_scenarioJson) as Map<String, dynamic>;
    state = ScenarioLoader.fromJson(json, kShipDefinitions);
  });

  test('correct squad count', () {
    expect(state.squads.length, 3);
  });

  test('enemy raidPack squad has 6 ship instance IDs', () {
    final raidSquad = state.squads['e_raid_1']!;
    expect(raidSquad.shipInstanceIds.length, 6);
  });

  test('correct total ship count', () {
    // 1 (p_flagship) + 1 (e_flagship) + 6 (e_raid_1) = 8
    expect(state.ships.length, 8);
  });

  test('playerFlagshipId is the flagship squad leader', () {
    expect(state.playerFlagshipId, 'p_flagship_ship_0');
    expect(state.playerFlagship?.dataId, 'flagship');
  });

  test('enemyFlagshipId is the enemy flagship squad leader', () {
    expect(state.enemyFlagshipId, 'e_flagship_ship_0');
    expect(state.enemyFlagship?.dataId, 'flagship');
  });

  test('win condition targets enemy flagship ship', () {
    final wc = state.winCondition!;
    expect(wc.type, WinConditionType.destroyEnemyFlagship);
    expect(wc.targetShipId, 'e_flagship_ship_0');
  });

  test('playerBudget parsed correctly', () {
    expect(state.playerBudget, 8);
  });

  test('availableSquadTypes parsed correctly', () {
    expect(state.availableSquadTypes, [SquadType.lineDivision, SquadType.raidPack]);
  });

  test('ships have squadId back-reference', () {
    expect(state.ships['p_flagship_ship_0']?.squadId, 'p_flagship');
    expect(state.ships['e_raid_1_ship_0']?.squadId, 'e_raid_1');
    expect(state.ships['e_raid_1_ship_5']?.squadId, 'e_raid_1');
  });

  test('squad convenience getters work', () {
    expect(state.playerSquads.length, 1);
    expect(state.enemySquads.length, 2);
  });

  test('durability set from ShipData.maxDurability', () {
    final flagship = state.ships['p_flagship_ship_0']!;
    expect(flagship.durability, kShipDefinitions['flagship']!.maxDurability);

    final raider = state.ships['e_raid_1_ship_0']!;
    expect(raider.durability, kShipDefinitions['fast_raider']!.maxDurability);
  });
}
