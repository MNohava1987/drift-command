import 'dart:math' as math;
import 'package:flame/components.dart';
import '../models/battle_state.dart';
import '../models/ship_data.dart';
import '../models/squad.dart';

/// Maintains formation cohesion each tick.
///
/// Run AFTER KinematicSystem so follower targets reflect the leader's new position.
/// 1. Propagate squad.activeOrder to the squad leader.
/// 2. Sync centroid/heading/velocity from leader.
/// 3. Issue formation moveTo orders to all non-leader ships.
class SquadSystem {
  void update(BattleState state) {
    for (final squad in state.squads.values) {
      final members = squad.shipInstanceIds
          .map((id) => state.ships[id])
          .whereType<ShipState>()
          .where((s) => s.isAlive)
          .toList();
      if (members.isEmpty) continue;

      // Leader: first alive ship in the instanceId list
      final leader = members.first;

      // Propagate squad order to leader
      if (squad.activeOrder != null) {
        leader.activeOrder = squad.activeOrder;
      }

      // Sync centroid/heading/velocity from leader
      squad.centroid = leader.position.clone();
      squad.heading = leader.heading;
      squad.velocity = leader.velocity.clone();

      // Non-leaders: move to their formation slot
      final offsets = SquadState.formationOffsets(squad.type);
      var memberIdx = 1; // skip leader (index 0 in members list)
      for (var i = 1; i < squad.shipInstanceIds.length; i++) {
        final ship = state.ships[squad.shipInstanceIds[i]];
        if (ship == null || !ship.isAlive) continue;
        final offset =
            memberIdx < offsets.length ? offsets[memberIdx] : Vector2.zero();
        memberIdx++;

        final cosH = math.cos(squad.heading);
        final sinH = math.sin(squad.heading);
        final targetPos = squad.centroid +
            Vector2(
              offset.x * cosH - offset.y * sinH,
              offset.x * sinH + offset.y * cosH,
            );
        ship.activeOrder = Order(
          type: OrderType.moveTo,
          targetPosition: targetPos,
          targetSpeedFraction: 1.0,
        );
      }
    }
  }
}
