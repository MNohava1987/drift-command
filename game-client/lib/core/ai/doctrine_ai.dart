import 'package:flame/components.dart';
import '../models/ship_data.dart';
import '../models/battle_state.dart';
import '../models/squad.dart';
import '../systems/command_system.dart';
import '../systems/engagement_system.dart';

/// Doctrine-driven AI for enemy factions.
/// Operates at squad level. Re-evaluates on an interval scaled to tempo band.
class DoctrineAI {
  final CommandSystem commandSystem;
  final EngagementSystem engagementSystem;
  final Map<String, ShipData> registry;

  double _nextAIUpdate = 0;

  static const Map<TempoBand, double> _aiInterval = {
    TempoBand.distant: 15.0,
    TempoBand.contact: 7.0,
    TempoBand.engaged: 3.0,
  };

  DoctrineAI({
    required this.commandSystem,
    required this.engagementSystem,
    required this.registry,
  });

  void update(BattleState state, double dt) {
    if (state.battleTime < _nextAIUpdate) return;
    _nextAIUpdate =
        state.battleTime + (_aiInterval[state.tempoBand] ?? 3.0);

    // Set ShipMode on all ships based on faction posture
    for (final ship in state.ships.values) {
      if (!ship.isAlive || ship.factionId == state.playerFactionId) continue;
      final posture =
          state.factionPostures[ship.factionId] ?? AiPosture.aggressive;
      ship.shipMode =
          (posture == AiPosture.aggressive || posture == AiPosture.flanking)
              ? ShipMode.attack
              : ShipMode.defensive;
    }

    // Squad-level posture orders for each enemy faction
    final factionIds = state.squads.values
        .map((sq) => sq.factionId)
        .toSet()
        .where((id) => id != state.playerFactionId);

    for (final factionId in factionIds) {
      _runFactionAI(state, factionId);
    }

    // Engagement system handles contact-range behaviour for ENGAGE/GHOST squads
    engagementSystem.update(state);
  }

  void _runFactionAI(BattleState state, int factionId) {
    final mySquads = state.squads.values
        .where((sq) => sq.factionId == factionId && state.squadIsAlive(sq))
        .toList();

    final playerFlagshipSquad = state.playerFlagshipSquad;
    if (playerFlagshipSquad == null || !state.squadIsAlive(playerFlagshipSquad)) {
      // No alive player flagship squad — skip (player already losing)
      return;
    }

    final posture =
        state.factionPostures[factionId] ?? AiPosture.aggressive;

    for (final squad in mySquads) {
      _applySquadPosture(
        state: state,
        squad: squad,
        posture: posture,
        playerFlagshipSquad: playerFlagshipSquad,
      );
    }
  }

  void _applySquadPosture({
    required BattleState state,
    required SquadState squad,
    required AiPosture posture,
    required SquadState playerFlagshipSquad,
  }) {
    final leaderShipId = playerFlagshipSquad.shipInstanceIds.firstOrNull;
    final leaderShip =
        leaderShipId != null ? state.ships[leaderShipId] : null;

    switch (posture) {
      case AiPosture.aggressive:
        if (leaderShip != null && leaderShip.isAlive) {
          commandSystem.issueSquadOrder(
            state: state,
            squadId: squad.squadId,
            orderType: OrderType.attackTarget,
            targetPosition: leaderShip.position.clone(),
            targetEnemyId: leaderShip.instanceId,
          );
        }

      case AiPosture.defensive:
        final nearPlayer = state.playerSquads.any(
          (psq) =>
              state.squadIsAlive(psq) &&
              psq.centroid.distanceTo(squad.centroid) <= 200,
        );
        if (!nearPlayer) {
          commandSystem.issueSquadOrder(
            state: state,
            squadId: squad.squadId,
            orderType: OrderType.hold,
          );
        }

      case AiPosture.flanking:
        // Move to 150 units lateral from player flagship centroid
        final toFlagship =
            playerFlagshipSquad.centroid - squad.centroid;
        if (toFlagship.length > 0.1) {
          final perp = Vector2(-toFlagship.y, toFlagship.x).normalized() * 150;
          commandSystem.issueSquadOrder(
            state: state,
            squadId: squad.squadId,
            orderType: OrderType.moveTo,
            targetPosition: playerFlagshipSquad.centroid + perp,
          );
        }

      case AiPosture.holdAndFire:
        commandSystem.issueSquadOrder(
          state: state,
          squadId: squad.squadId,
          orderType: OrderType.hold,
        );
    }
  }
}
