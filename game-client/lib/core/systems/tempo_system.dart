import '../models/battle_state.dart';

/// Pulse durations in seconds per tempo band.
/// This is the total cycle time: window open + cooldown before next window.
const Map<TempoBand, double> kPulseDuration = {
  TempoBand.distant: 15.0,
  TempoBand.contact: 7.0,
  TempoBand.engaged: 3.0,
};

/// How long the command window stays open within each pulse cycle.
/// During the window, any number of ships can receive orders for free.
/// After the window closes, the full cooldown runs before the next window.
const Map<TempoBand, double> kWindowDuration = {
  TempoBand.distant: 6.0,   // 6-second ordering window per 15-second cycle
  TempoBand.contact: 3.5,   // 3.5-second window per 7-second cycle
  TempoBand.engaged: 2.0,   // 2-second window per 3-second cycle
};

/// Thresholds for band transitions.
/// Contact: any enemy within 2× weapon range of any player ship.
/// Engaged: any weapon fire occurring (tracked separately).
const double kContactRangeMultiplier = 2.0;

/// Evaluates the current tempo band and manages the command pulse window.
///
/// The command system uses a windowed model: when a pulse fires, a window
/// opens for [kWindowDuration] seconds. Any number of orders can be issued
/// freely during this window. After the window closes, the next window opens
/// after [kPulseDuration] seconds from the previous window's opening.
///
/// This allows fleet-wide orchestration — you can issue orders to all your
/// ships in a single burst, then wait for the next pulse.
class TempoSystem {
  void update(BattleState state, double dt) {
    state.battleTime += dt;

    final newBand = _evaluateBand(state);
    if (newBand != state.tempoBand) {
      state.tempoBand = newBand;
      // Band change opens a new window immediately
      _openWindow(state);
      return;
    }

    // Auto-open the next window when the scheduled pulse fires and the
    // previous window has already closed.
    if (state.commandWindowEnd != double.infinity &&
        state.battleTime >= state.commandWindowEnd &&
        state.battleTime >= state.nextCommandPulse) {
      _openWindow(state);
    }
  }

  /// Called by [BattleGame] after the player successfully issues an order.
  ///
  /// On the very first order of the game (while the initial infinite window
  /// is open), this starts the pulse cycle. During a normal timed window,
  /// this is a no-op — the window stays open until [commandWindowEnd].
  void advanceCommandPulse(BattleState state) {
    if (state.commandWindowEnd == double.infinity) {
      // First ever order: replace the infinite initial window with a timed one.
      _openWindow(state);
    }
    // Otherwise: already in a timed window — window closes naturally.
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

  /// Opens a new command window and schedules the next one.
  void _openWindow(BattleState state) {
    state.commandWindowEnd =
        state.battleTime + kWindowDuration[state.tempoBand]!;
    state.nextCommandPulse =
        state.battleTime + kPulseDuration[state.tempoBand]!;
  }

  /// True while the command window is open (orders may be issued).
  bool isCommandPulseReady(BattleState state) {
    return state.battleTime < state.commandWindowEnd;
  }
}
