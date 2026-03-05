import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../game/battle_game.dart';
import '../widgets/hud_overlay.dart';

/// Root Flutter screen. Hosts the Flame game inside a [GameWidget] and
/// registers overlay builders for the HUD, win screen, and lose screen.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final BattleGame _game;

  @override
  void initState() {
    super.initState();
    _game = BattleGame();
  }

  @override
  Widget build(BuildContext context) {
    return GameWidget<BattleGame>(
      game: _game,
      overlayBuilderMap: {
        'hud': (_, game) => HudOverlay(game: game),
        'win': (_, game) => _EndScreen(
              message: 'VICTORY',
              color: const Color(0xFF4A90D9),
              game: game,
            ),
        'lose': (_, game) => _EndScreen(
              message: 'DEFEATED',
              color: const Color(0xFFD94A4A),
              game: game,
            ),
      },
    );
  }
}

// ── End-of-battle overlay ─────────────────────────────────────────────────────

class _EndScreen extends StatelessWidget {
  final String message;
  final Color color;
  // ignore: unused_field
  final BattleGame game;

  const _EndScreen({
    required this.message,
    required this.color,
    required this.game,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withAlpha(200),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              style: TextStyle(
                color: color,
                fontSize: 48,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Restart to play again',
              style: TextStyle(color: color.withAlpha(180), fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
