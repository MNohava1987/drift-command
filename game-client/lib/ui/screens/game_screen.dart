import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/ships/ship_definitions.dart';
import '../../game/battle_game.dart';
import '../widgets/hud_overlay.dart';
import 'scenario_picker_screen.dart';

/// Ordered scenario progression list (same order as picker).
const _scenarioOrder = [
  'assets/scenarios/scenario_001.json',
  'assets/scenarios/scenario_002.json',
  'assets/scenarios/scenario_003.json',
  'assets/scenarios/scenario_004.json',
  'assets/scenarios/scenario_005.json',
];

const _scenarioIds = [
  'scenario_001',
  'scenario_002',
  'scenario_003',
  'scenario_004',
  'scenario_005',
];

/// Root Flutter screen. Hosts the Flame game inside a [GameWidget] and
/// registers overlay builders for the HUD, win screen, and lose screen.
class GameScreen extends StatefulWidget {
  final String scenarioAssetPath;
  final String scenarioId;
  final bool carryDamage;
  final Map<String, double>? startingDurabilityFractions;

  const GameScreen({
    super.key,
    this.scenarioAssetPath = 'assets/scenarios/scenario_001.json',
    this.scenarioId = 'scenario_001',
    this.carryDamage = false,
    this.startingDurabilityFractions,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final BattleGame _game;

  @override
  void initState() {
    super.initState();
    _game = BattleGame(
      scenarioAssetPath: widget.scenarioAssetPath,
      carryDamage: widget.carryDamage,
      startingDurabilityFractions: widget.startingDurabilityFractions,
    );
  }

  void _restart() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => GameScreen(
          scenarioId: widget.scenarioId,
          scenarioAssetPath: widget.scenarioAssetPath,
        ),
      ),
    );
  }

  void _backToMenu() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const ScenarioPickerScreen()),
    );
  }

  /// Save completion and durability fractions, then push next scenario.
  Future<void> _goNextScenario() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('completed_${widget.scenarioId}', true);
    _saveDurabilityFractions(prefs);

    final currentIdx = _scenarioIds.indexOf(widget.scenarioId);
    if (currentIdx < 0 || currentIdx + 1 >= _scenarioOrder.length) {
      _backToMenu();
      return;
    }

    final nextPath = _scenarioOrder[currentIdx + 1];
    final nextId = _scenarioIds[currentIdx + 1];
    final fractions = _buildDurabilityFractions();

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => GameScreen(
          scenarioId: nextId,
          scenarioAssetPath: nextPath,
          carryDamage: true,
          startingDurabilityFractions: fractions,
        ),
      ),
    );
  }

  Future<void> _saveWin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('completed_${widget.scenarioId}', true);
    _saveDurabilityFractions(prefs);
  }

  void _saveDurabilityFractions(SharedPreferences prefs) {
    final state = _game.battleStateOrNull;
    if (state == null) return;
    for (final ship in state.playerShips) {
      final data = kShipDefinitions[ship.dataId];
      if (data == null) continue;
      final fraction = (ship.durability / data.maxDurability).clamp(0.0, 1.0);
      prefs.setDouble('durability_fraction_${ship.dataId}', fraction);
    }
  }

  Map<String, double> _buildDurabilityFractions() {
    final state = _game.battleStateOrNull;
    if (state == null) return {};
    final fractions = <String, double>{};
    for (final ship in state.playerShips) {
      final data = kShipDefinitions[ship.dataId];
      if (data == null) continue;
      fractions[ship.dataId] =
          (ship.durability / data.maxDurability).clamp(0.0, 1.0);
    }
    return fractions;
  }

  bool get _hasNextScenario {
    final idx = _scenarioIds.indexOf(widget.scenarioId);
    return idx >= 0 && idx + 1 < _scenarioOrder.length;
  }

  @override
  Widget build(BuildContext context) {
    return GameWidget<BattleGame>(
      game: _game,
      overlayBuilderMap: {
        'hud': (context, game) => HudOverlay(
              game: game,
              onRestart: _restart,
              onBackToMenu: _backToMenu,
            ),
        'win': (context, _) => _WinScreen(
              hasNext: _hasNextScenario,
              onBackToMenu: () {
                _saveWin();
                _backToMenu();
              },
              onNextScenario: _goNextScenario,
            ),
        'lose': (context, _) => _EndScreen(
              message: 'DEFEATED',
              color: const Color(0xFFD94A4A),
              onBackToMenu: _backToMenu,
            ),
      },
    );
  }
}

// ── Win screen ─────────────────────────────────────────────────────────────────

class _WinScreen extends StatelessWidget {
  final bool hasNext;
  final VoidCallback onBackToMenu;
  final VoidCallback onNextScenario;

  const _WinScreen({
    required this.hasNext,
    required this.onBackToMenu,
    required this.onNextScenario,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withAlpha(200),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'VICTORY',
              style: TextStyle(
                color: Color(0xFF4A90D9),
                fontSize: 48,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 32),
            _EndButton(
              label: 'BACK TO MENU',
              color: const Color(0xFF4A90D9),
              onPressed: onBackToMenu,
            ),
            if (hasNext) ...[
              const SizedBox(height: 12),
              _EndButton(
                label: 'NEXT SCENARIO',
                color: const Color(0xFF50D9A0),
                onPressed: onNextScenario,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Defeat screen ──────────────────────────────────────────────────────────────

class _EndScreen extends StatelessWidget {
  final String message;
  final Color color;
  final VoidCallback onBackToMenu;

  const _EndScreen({
    required this.message,
    required this.color,
    required this.onBackToMenu,
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
            _EndButton(
              label: 'BACK TO MENU',
              color: color,
              onPressed: onBackToMenu,
            ),
          ],
        ),
      ),
    );
  }
}

class _EndButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _EndButton({
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: color.withAlpha(180)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }
}
