import '../models/battle_state.dart';

/// Pulse durations in seconds per tempo band.
/// The command system respects these windows — players can only issue
/// new orders at the start of each pulse.
const Map<TempoBand, double> kPulseDuration = {
  TempoBand.distant: 15.0,
  TempoBand.contact: 7.0,
  TempoBand.engaged: 3.0,
};

/// Thresholds for band transitions.
/// Contact: any enemy within 2× weapon range of any player ship.
/// Engaged: any weapon fire occurring (tracked separately).
const double kContactRangeMultiplier = 2.0;

/// Evaluates the current tempo band and updates the command pulse timer.
class TempoSystem {
  void update(BattleState state, double dt) {
    state.battleTime += dt;

    final newBand = _evaluateBand(state);
    if (newBand != state.tempoBand) {
      state.tempoBand = newBand;
      // Band change resets the pulse so the new window opens immediately
      state.nextCommandPulse = state.battleTime;
    }
  }

  /// Called by [BattleGame] after the player successfully issues an order.
  /// Closes the current window and schedules the next one.
  void advanceCommandPulse(BattleState state) {
    state.nextCommandPulse =
        state.battleTime + kPulseDuration[state.tempoBand]!;
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

    // Use a representative weapon range — can be made per-ship later
    const double representativeWeaponRange = 150.0;

    if (minDistance <= representativeWeaponRange) {
      return TempoBand.engaged;
    } else if (minDistance <= representativeWeaponRange * kContactRangeMultiplier) {
      return TempoBand.contact;
    } else {
      return TempoBand.distant;
    }
  }

  /// True if the current time is at or past the next command pulse.
  bool isCommandPulseReady(BattleState state) {
    return state.battleTime >= state.nextCommandPulse;
  }
}
