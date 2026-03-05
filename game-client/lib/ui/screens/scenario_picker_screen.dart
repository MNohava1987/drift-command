import 'package:flutter/material.dart';

import 'game_screen.dart';
import 'tutorial_screen.dart';

/// Scenario metadata for the picker UI.
class _ScenarioMeta {
  final String assetPath;
  final String title;
  final String description;
  final String difficulty;

  const _ScenarioMeta({
    required this.assetPath,
    required this.title,
    required this.description,
    required this.difficulty,
  });
}

const _scenarios = [
  _ScenarioMeta(
    assetPath: 'assets/scenarios/scenario_001.json',
    title: 'First Contact',
    description: '4 vs 4 — destroy the enemy flagship.',
    difficulty: 'NORMAL',
  ),
  _ScenarioMeta(
    assetPath: 'assets/scenarios/scenario_002.json',
    title: 'Relay Hunt',
    description: '3 vs 7 — destroy all enemies. Keep your relay alive.',
    difficulty: 'HARD',
  ),
  _ScenarioMeta(
    assetPath: 'assets/scenarios/scenario_003.json',
    title: 'Holding Action',
    description: '4 vs 9 — survive for 2 minutes.',
    difficulty: 'BRUTAL',
  ),
];

/// Pre-game screen that lets the player choose a scenario.
class ScenarioPickerScreen extends StatelessWidget {
  const ScenarioPickerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'DRIFT COMMAND',
              style: TextStyle(
                color: Color(0xFF4A90D9),
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'SELECT SCENARIO',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 12,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 40),
            ..._scenarios.map((s) => _ScenarioCard(meta: s)),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TutorialScreen()),
              ),
              child: const Text(
                'HOW TO PLAY',
                style: TextStyle(
                  color: Colors.white30,
                  fontSize: 11,
                  letterSpacing: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScenarioCard extends StatelessWidget {
  final _ScenarioMeta meta;

  const _ScenarioCard({required this.meta});

  Color get _difficultyColor => switch (meta.difficulty) {
        'NORMAL' => const Color(0xFF4A90D9),
        'HARD' => const Color(0xFFE8A030),
        _ => const Color(0xFFD94A4A),
      };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 24),
      child: GestureDetector(
        onTap: () => Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => GameScreen(scenarioAssetPath: meta.assetPath),
          ),
        ),
        child: Container(
          width: 420,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white12),
            borderRadius: BorderRadius.circular(6),
            color: Colors.white.withAlpha(8),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meta.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      meta.description,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: _difficultyColor.withAlpha(180)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  meta.difficulty,
                  style: TextStyle(
                    color: _difficultyColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
