import 'package:flame/components.dart';
import '../models/battle_state.dart';
import '../models/ship_data.dart';
import '../models/squad.dart';
import 'command_system.dart';

/// Range at which squads switch from their route to active engagement.
const double kContactRange = 250.0;

/// Applies engagement-mode behaviour for AI (non-player) squads.
///
/// Runs at the AI tick rate (tempo-gated by DoctrineAI), NOT every frame.
/// For each enemy squad within kContactRange of a player squad:
///   DIRECT  — no change, squad follows its active order
///   ENGAGE  — attack the nearest player squad's leader ship
///   GHOST   — lateral evade 180 units perpendicular to contact direction
class EngagementSystem {
  final CommandSystem commandSystem;
  final Map<String, ShipData> registry;

  EngagementSystem({required this.commandSystem, required this.registry});

  void update(BattleState state) {
    for (final squad in state.squads.values) {
      if (!state.squadIsAlive(squad)) continue;
      if (squad.factionId == state.playerFactionId) continue;

      // Find nearest alive player squad by centroid distance
      SquadState? nearest;
      double nearestDist = double.infinity;
      for (final playerSquad in state.playerSquads) {
        if (!state.squadIsAlive(playerSquad)) continue;
        final d = squad.centroid.distanceTo(playerSquad.centroid);
        if (d < nearestDist) {
          nearestDist = d;
          nearest = playerSquad;
        }
      }
      if (nearest == null || nearestDist > kContactRange) continue;

      switch (squad.engagementMode) {
        case EngagementMode.direct:
          break; // hold current order unchanged

        case EngagementMode.engage:
          final leaderId = nearest.shipInstanceIds.firstOrNull;
          final leaderShip = leaderId != null ? state.ships[leaderId] : null;
          if (leaderShip != null && leaderShip.isAlive) {
            commandSystem.issueSquadOrder(
              state: state,
              squadId: squad.squadId,
              orderType: OrderType.attackTarget,
              targetPosition: leaderShip.position.clone(),
              targetEnemyId: leaderShip.instanceId,
            );
          }

        case EngagementMode.ghost:
          final toContact = nearest.centroid - squad.centroid;
          if (toContact.length > 0.1) {
            final perp = Vector2(-toContact.y, toContact.x).normalized() * 180;
            commandSystem.issueSquadOrder(
              state: state,
              squadId: squad.squadId,
              orderType: OrderType.moveTo,
              targetPosition: squad.centroid + perp,
            );
          }
      }
    }
  }
}
