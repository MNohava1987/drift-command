import '../models/battle_state.dart';
import '../../data/game_config.dart';

/// Evaluates the current tempo band based on proximity of opposing fleets.
///
/// The band is used only by DoctrineAI to set its re-evaluation interval —
/// the enemy re-plans more frequently when fleets are close.
///
/// Command windows and pulse gating have been removed. The player can issue
/// orders at any time.
class TempoSystem {
  void update(BattleState state, double dt) {
    state.battleTime += dt;
    state.tempoBand = _evaluateBand(state);
  }

  TempoBand _evaluateBand(BattleState state) {
    final playerShips = state.playerShips.where((s) => s.isAlive).toList();
    final enemyShips = state.enemyShips.where((s) => s.isAlive).toList();

    if (playerShips.isEmpty || enemyShips.isEmpty) return TempoBand.distant;

    double minDistance = double.infinity;
    for (final p in playerShips) {
      for (final e in enemyShips) {
        final d = p.position.distanceTo(e.position);
        if (d < minDistance) minDistance = d;
      }
    }

    if (minDistance <= kRepresentativeWeaponRange) return TempoBand.engaged;
    if (minDistance <= kRepresentativeWeaponRange * 2.0) return TempoBand.contact;
    return TempoBand.distant;
  }
}
