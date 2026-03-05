import 'package:flutter/material.dart';

import '../../core/models/battle_state.dart';
import '../../core/models/ship_data.dart';
import '../../game/battle_game.dart';

/// In-game HUD rendered over the Flame canvas via FlameGame overlays.
class HudOverlay extends StatelessWidget {
  final BattleGame game;

  const HudOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TopBar(game: game),
        const Spacer(),
        _ActionBar(game: game),
        _ShipInfoBar(game: game),
      ],
    );
  }
}

// ── Top bar ───────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final BattleGame game;

  const _TopBar({required this.game});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withAlpha(160),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          ValueListenableBuilder<TempoBand>(
            valueListenable: game.tempoBandNotifier,
            builder: (_, band, _) => _TempoPill(band: band),
          ),
          const SizedBox(width: 12),
          ValueListenableBuilder<String>(
            valueListenable: game.battleTimeTextNotifier,
            builder: (_, text, _) => Text(
              text,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              game.battleStateOrNull?.objectiveDescription ?? '',
              style: const TextStyle(color: Colors.white60, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          ValueListenableBuilder<bool>(
            valueListenable: game.isPausedNotifier,
            builder: (_, paused, _) => GestureDetector(
              onTap: game.togglePause,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: paused ? Colors.amber : Colors.white24,
                  ),
                  borderRadius: BorderRadius.circular(4),
                  color: paused
                      ? Colors.amber.withAlpha(30)
                      : Colors.transparent,
                ),
                child: Text(
                  paused ? 'RESUME' : 'PAUSE',
                  style: TextStyle(
                    color: paused ? Colors.amber : Colors.white54,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TempoPill extends StatelessWidget {
  final TempoBand band;

  const _TempoPill({required this.band});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (band) {
      TempoBand.distant => ('DISTANT', const Color(0xFF4A90D9)),
      TempoBand.contact => ('CONTACT', const Color(0xFFE8A030)),
      TempoBand.engaged => ('ENGAGED', const Color(0xFFD94A4A)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(220),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// ── Action bar ────────────────────────────────────────────────────────────────

class _ActionBar extends StatelessWidget {
  final BattleGame game;

  const _ActionBar({required this.game});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ShipState?>(
      valueListenable: game.selectedShipNotifier,
      builder: (_, ship, _) {
        final state = game.battleStateOrNull;
        if (ship == null || state == null) return const SizedBox.shrink();
        if (ship.factionId != state.playerFactionId) {
          return const SizedBox.shrink();
        }
        return ValueListenableBuilder<bool>(
          valueListenable: game.commandPulseReadyNotifier,
          builder: (_, pulseReady, _) {
            return Container(
              color: Colors.black.withAlpha(140),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _SpeedSelector(game: game),
                  const SizedBox(width: 16),
                  _CommandButton(
                    label: 'HOLD',
                    enabled: pulseReady,
                    onPressed: game.issueHold,
                  ),
                  const SizedBox(width: 8),
                  _CommandButton(
                    label: 'RETREAT',
                    enabled: pulseReady,
                    onPressed: game.issueRetreat,
                  ),
                  const SizedBox(width: 8),
                  _CommandButton(
                    label: 'CANCEL',
                    enabled: true,
                    onPressed: game.cancelOrders,
                  ),
                  const SizedBox(width: 12),
                  _PulseIndicator(ready: pulseReady),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _SpeedSelector extends StatefulWidget {
  final BattleGame game;
  const _SpeedSelector({required this.game});
  @override
  State<_SpeedSelector> createState() => _SpeedSelectorState();
}

class _SpeedSelectorState extends State<_SpeedSelector> {
  static const _speeds = [
    (label: 'SLOW', value: 0.25),
    (label: 'MED', value: 0.5),
    (label: 'FAST', value: 1.0),
  ];

  @override
  Widget build(BuildContext context) {
    final selected = widget.game.selectedSpeed;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: _speeds.map((s) {
        final isSelected = selected == s.value;
        return GestureDetector(
          onTap: () => setState(() => widget.game.selectedSpeed = s.value),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF4A90D9)
                    : Colors.white24,
              ),
              borderRadius: BorderRadius.circular(4),
              color: isSelected
                  ? const Color(0xFF4A90D9).withAlpha(60)
                  : Colors.transparent,
            ),
            child: Text(
              s.label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white38,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _CommandButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback onPressed;

  const _CommandButton({
    required this.label,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onPressed : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          border: Border.all(
            color: enabled
                ? const Color(0xFF4A90D9)
                : Colors.white24,
          ),
          borderRadius: BorderRadius.circular(4),
          color: enabled
              ? const Color(0xFF4A90D9).withAlpha(40)
              : Colors.transparent,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: enabled ? Colors.white : Colors.white30,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
      ),
    );
  }
}

class _PulseIndicator extends StatelessWidget {
  final bool ready;

  const _PulseIndicator({required this.ready});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: ready ? Colors.greenAccent : Colors.white24,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          ready ? 'CMD READY' : 'CMD WAIT',
          style: TextStyle(
            color: ready ? Colors.greenAccent : Colors.white30,
            fontSize: 9,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}

// ── Ship info bar ─────────────────────────────────────────────────────────────

class _ShipInfoBar extends StatelessWidget {
  final BattleGame game;

  const _ShipInfoBar({required this.game});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ShipState?>(
      valueListenable: game.selectedShipNotifier,
      builder: (_, ship, _) {
        final state = game.battleStateOrNull;
        if (ship == null || state == null) return const SizedBox.shrink();
        if (ship.factionId != state.playerFactionId) {
          return const SizedBox.shrink();
        }
        return _ShipPanel(ship: ship, state: state);
      },
    );
  }
}

class _ShipPanel extends StatelessWidget {
  final ShipState ship;
  final BattleState state;

  const _ShipPanel({required this.ship, required this.state});

  @override
  Widget build(BuildContext context) {
    final topology = state.topologies[ship.factionId];
    final isConnected = topology != null
        ? topology.isConnected(
            ship.instanceId,
            state.aliveMap,
            assignedCommandNodeId: ship.assignedCommandNodeId,
          )
        : false;

    return Container(
      color: Colors.black.withAlpha(170),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                ship.instanceId.replaceAll('_', ' ').toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                ship.dataId.replaceAll('_', ' '),
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(width: 16),
          _DurabilityBar(ship: ship),
          const SizedBox(width: 16),
          _RelayStatus(connected: isConnected),
        ],
      ),
    );
  }
}

class _DurabilityBar extends StatelessWidget {
  final ShipState ship;

  const _DurabilityBar({required this.ship});

  @override
  Widget build(BuildContext context) {
    // Approximate max durability from ship data or fallback
    const maxDurs = <String, double>{
      'flagship': 200.0,
      'command_relay': 80.0,
      'heavy_line': 120.0,
      'light_escort': 50.0,
      'strike_carrier': 90.0,
      'fast_raider': 40.0,
    };
    final maxDur = maxDurs[ship.dataId] ?? 100.0;
    final frac = (ship.durability / maxDur).clamp(0.0, 1.0);
    final barColor = frac > 0.5
        ? Colors.greenAccent
        : frac > 0.25
            ? Colors.orange
            : Colors.redAccent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'HP ${ship.durability.toStringAsFixed(0)}',
          style: const TextStyle(color: Colors.white60, fontSize: 10),
        ),
        const SizedBox(height: 2),
        SizedBox(
          width: 80,
          height: 6,
          child: Stack(
            children: [
              Container(color: Colors.white12),
              FractionallySizedBox(
                widthFactor: frac,
                child: Container(color: barColor),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RelayStatus extends StatelessWidget {
  final bool connected;

  const _RelayStatus({required this.connected});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          connected ? Icons.link : Icons.link_off,
          color: connected ? Colors.greenAccent : Colors.redAccent,
          size: 14,
        ),
        const SizedBox(width: 4),
        Text(
          connected ? 'RELAY OK' : 'ISOLATED',
          style: TextStyle(
            color: connected ? Colors.greenAccent : Colors.redAccent,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
