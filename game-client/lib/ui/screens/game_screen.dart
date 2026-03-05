import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../game/battle_game.dart';
import '../widgets/hud_overlay.dart';
import 'scenario_picker_screen.dart';

/// Root Flutter screen. Hosts the Flame game inside a [GameWidget] and
/// registers overlay builders for the HUD, win screen, and lose screen.
class GameScreen extends StatefulWidget {
  final String scenarioAssetPath;

  const GameScreen({
    super.key,
    this.scenarioAssetPath = 'assets/scenarios/scenario_001.json',
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final BattleGame _game;

  @override
  void initState() {
    super.initState();
    _game = BattleGame(scenarioAssetPath: widget.scenarioAssetPath);
  }

  @override
  Widget build(BuildContext context) {
    return GameWidget<BattleGame>(
      game: _game,
      overlayBuilderMap: {
        'hud': (_, game) => HudOverlay(game: game),
        'win': (context, game) => _EndScreen(
              message: 'VICTORY',
              color: const Color(0xFF4A90D9),
              context: context,
            ),
        'lose': (context, game) => _EndScreen(
              message: 'DEFEATED',
              color: const Color(0xFFD94A4A),
              context: context,
            ),
      },
    );
  }
}

// ── End-of-battle overlay ─────────────────────────────────────────────────────

class _EndScreen extends StatelessWidget {
  final String message;
  final Color color;
  final BuildContext context;

  const _EndScreen({
    required this.message,
    required this.color,
    required this.context,
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
            const SizedBox(height: 32),
            GestureDetector(
              onTap: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => const ScenarioPickerScreen(),
                ),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: color.withAlpha(180)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'BACK TO MENU',
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
