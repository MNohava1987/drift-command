import 'dart:math' as math;
import 'package:flame/components.dart';
import '../models/ship_data.dart';
import '../models/battle_state.dart';
import '../models/squad.dart';

/// Parses a squad-based scenario JSON map into a ready-to-run [BattleState].
///
/// JSON format uses playerSquads/enemySquads arrays. Each squad entry specifies
/// type, position, heading, and engagementMode. Ships are generated from squad
/// definitions — instance IDs follow the pattern "{squadId}_ship_{index}".
///
/// carryDamage and startingDurabilityFractions are accepted for backwards
/// compatibility but are not applied — all ships always spawn at full health.
class ScenarioLoader {
  static BattleState fromJson(
    Map<String, dynamic> json,
    Map<String, ShipData> registry, {
    bool carryDamage = false,
    Map<String, double>? startingDurabilityFractions,
  }) {
    final playerFactionId = json['playerFactionId'] as int;
    final objective = json['objective'] as String;
    final playerBudget = (json['playerBudget'] as num?)?.toInt() ?? 0;

    final availableSquadTypes = <SquadType>[];
    if (json.containsKey('availableSquadTypes')) {
      for (final typeStr in json['availableSquadTypes'] as List<dynamic>) {
        final t = _parseSquadType(typeStr as String);
        if (t != null) availableSquadTypes.add(t);
      }
    }

    final shipsMap = <String, ShipState>{};
    final squadsMap = <String, SquadState>{};
    String? playerFlagshipId;
    String? enemyFlagshipId;
    String? enemyFlagshipSquadId;

    // Player squads
    if (json.containsKey('playerSquads')) {
      for (final squadJson in json['playerSquads'] as List<dynamic>) {
        final sq = squadJson as Map<String, dynamic>;
        final squad = _parseSquad(sq, playerFactionId, registry, shipsMap);
        squadsMap[squad.squadId] = squad;
        if (squad.type == SquadType.flagship) {
          playerFlagshipId = '${squad.squadId}_ship_0';
        }
      }
    }

    // Enemy squads
    if (json.containsKey('enemySquads')) {
      for (final squadJson in json['enemySquads'] as List<dynamic>) {
        final sq = squadJson as Map<String, dynamic>;
        final factionId = (sq['factionId'] as num?)?.toInt() ?? playerFactionId + 1;
        final squad = _parseSquad(sq, factionId, registry, shipsMap);
        squadsMap[squad.squadId] = squad;
        if (squad.type == SquadType.flagship && factionId != playerFactionId) {
          enemyFlagshipSquadId = squad.squadId;
          enemyFlagshipId = '${squad.squadId}_ship_0';
        }
      }
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
      // For destroyEnemyFlagship, compute targetShipId from enemy flagship squad
      String? targetShipId = wc['targetShipId'] as String?;
      if (wcType == WinConditionType.destroyEnemyFlagship &&
          targetShipId == null &&
          enemyFlagshipSquadId != null) {
        targetShipId = '${enemyFlagshipSquadId}_ship_0';
      }
      winCondition = WinCondition(
        type: wcType,
        targetShipId: targetShipId,
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
      squads: squadsMap,
      playerBudget: playerBudget,
      availableSquadTypes: availableSquadTypes,
      playerFlagshipId: playerFlagshipId ?? '',
      enemyFlagshipId: enemyFlagshipId,
      winCondition: winCondition,
      factionPostures: factionPostures,
    );
  }

  static SquadState _parseSquad(
    Map<String, dynamic> sq,
    int factionId,
    Map<String, ShipData> registry,
    Map<String, ShipState> shipsMap,
  ) {
    final squadId = sq['squadId'] as String;
    final type = _parseSquadType(sq['type'] as String) ?? SquadType.flagship;
    final posRaw = sq['position'] as List<dynamic>;
    final centroid = Vector2(
      (posRaw[0] as num).toDouble(),
      (posRaw[1] as num).toDouble(),
    );
    final heading = (sq['heading'] as num?)?.toDouble() ?? 0.0;
    final engagementMode =
        _parseEngagementMode(sq['engagementMode'] as String? ?? 'engage');

    final dataIds = SquadState.shipDataIds(type);
    final offsets = SquadState.formationOffsets(type);
    final instanceIds = <String>[];

    final cosH = math.cos(heading);
    final sinH = math.sin(heading);

    for (var i = 0; i < dataIds.length; i++) {
      final dataId = dataIds[i];
      final data = registry[dataId];
      if (data == null) continue;

      final offset = i < offsets.length ? offsets[i] : Vector2.zero();
      final rx = offset.x * cosH - offset.y * sinH;
      final ry = offset.x * sinH + offset.y * cosH;
      final worldPos = Vector2(centroid.x + rx, centroid.y + ry);

      final instanceId = '${squadId}_ship_$i';
      instanceIds.add(instanceId);

      shipsMap[instanceId] = ShipState(
        instanceId: instanceId,
        dataId: dataId,
        factionId: factionId,
        position: worldPos,
        heading: heading,
        durability: data.maxDurability,
        squadId: squadId,
      );
    }

    return SquadState(
      squadId: squadId,
      type: type,
      factionId: factionId,
      centroid: centroid,
      heading: heading,
      shipInstanceIds: instanceIds,
      engagementMode: engagementMode,
    );
  }

  static SquadType? _parseSquadType(String value) => switch (value) {
        // M6 types
        'flagship' => SquadType.flagship,
        'lineDivision' => SquadType.lineDivision,
        'raidPack' => SquadType.raidPack,
        'carrierStrike' => SquadType.carrierStrike,
        'escortScreen' => SquadType.escortScreen,
        // M7 types
        'gunboatPack' => SquadType.gunboatPack,
        'interceptorScreen' => SquadType.interceptorScreen,
        'flakLine' => SquadType.flakLine,
        'torpedoRun' => SquadType.torpedoRun,
        'cruiserDivision' => SquadType.cruiserDivision,
        'ewFlight' => SquadType.ewFlight,
        'carrierGroup' => SquadType.carrierGroup,
        'supportGroup' => SquadType.supportGroup,
        'battlecruiserGroup' => SquadType.battlecruiserGroup,
        'dreadnoughtGroup' => SquadType.dreadnoughtGroup,
        _ => null,
      };

  static EngagementMode _parseEngagementMode(String value) => switch (value) {
        'direct' => EngagementMode.direct,
        'ghost' => EngagementMode.ghost,
        _ => EngagementMode.engage,
      };

  static AiPosture _parsePosture(String value) => switch (value) {
        'aggressive' => AiPosture.aggressive,
        'defensive' => AiPosture.defensive,
        'flanking' => AiPosture.flanking,
        'holdAndFire' => AiPosture.holdAndFire,
        _ => AiPosture.aggressive,
      };
}
