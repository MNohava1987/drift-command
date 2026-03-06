import 'package:flame/components.dart';
import '../models/ship_data.dart';
import '../models/battle_state.dart';

/// Parses a scenario JSON map into a ready-to-run [BattleState].
///
/// The relay/topology system has been removed. Ships are identified directly
/// by role. The flagship for each faction is the ship with dataId 'flagship'.
class ScenarioLoader {
  static BattleState fromJson(
    Map<String, dynamic> json,
    Map<String, ShipData> registry, {
    bool carryDamage = false,
    Map<String, double>? startingDurabilityFractions,
  }) {
    final playerFactionId = json['playerFactionId'] as int;
    final objective = json['objective'] as String;

    final shipsMap = <String, ShipState>{};
    String? playerFlagshipId;
    String? enemyFlagshipId;

    for (final shipJson in json['ships'] as List<dynamic>) {
      final s = shipJson as Map<String, dynamic>;
      final instanceId = s['instanceId'] as String;
      final dataId = s['dataId'] as String;
      final factionId = s['factionId'] as int;
      final posRaw = s['position'] as List<dynamic>;
      final heading = (s['heading'] as num).toDouble();
      final data = registry[dataId];

      // Skip ships with unknown dataIds (e.g., removed ship types)
      if (data == null) continue;

      final maxDurability = data.maxDurability;
      double startDurability = maxDurability;
      if (carryDamage &&
          factionId == playerFactionId &&
          startingDurabilityFractions != null &&
          startingDurabilityFractions.containsKey(dataId)) {
        startDurability =
            maxDurability * startingDurabilityFractions[dataId]!.clamp(0.0, 1.0);
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

      shipsMap[instanceId] = ship;

      // Track flagships by role
      if (data.role == ShipRole.flagship) {
        if (factionId == playerFactionId) {
          playerFlagshipId = instanceId;
        } else {
          enemyFlagshipId = instanceId;
        }
      }
    }

    // Fallback: if no flagship role found, use first ship per faction
    if (playerFlagshipId == null) {
      playerFlagshipId = shipsMap.values
          .firstWhere((s) => s.factionId == playerFactionId)
          .instanceId;
    }
    if (enemyFlagshipId == null) {
      final enemy = shipsMap.values
          .where((s) => s.factionId != playerFactionId)
          .firstOrNull;
      enemyFlagshipId = enemy?.instanceId;
    }

    // Win condition
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

    // Faction postures
    final factionPostures = <int, AiPosture>{};
    if (json.containsKey('factionPostures')) {
      final postureJson = json['factionPostures'] as Map<String, dynamic>;
      for (final entry in postureJson.entries) {
        final fid = int.tryParse(entry.key);
        if (fid != null) {
          factionPostures[fid] = _parsePosture(entry.value as String);
        }
      }
    }

    return BattleState(
      playerFactionId: playerFactionId,
      objectiveDescription: objective,
      ships: shipsMap,
      playerFlagshipId: playerFlagshipId!,
      enemyFlagshipId: enemyFlagshipId,
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
