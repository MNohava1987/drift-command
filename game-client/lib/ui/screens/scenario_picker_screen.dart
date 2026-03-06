import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'deployment_screen.dart';
import 'tutorial_screen.dart';

/// Scenario metadata for the picker UI.
class _ScenarioMeta {
  final String id;
  final String assetPath;
  final String title;
  final String description;
  final String difficulty;
  final String? prerequisiteId;

  const _ScenarioMeta({
    required this.id,
    required this.assetPath,
    required this.title,
    required this.description,
    required this.difficulty,
    this.prerequisiteId,
  });
}

const _scenarios = [
  _ScenarioMeta(
    id: 'scenario_001',
    assetPath: 'assets/scenarios/scenario_001.json',
    title: 'First Contact',
    description: '4 vs 4 — destroy the enemy flagship.',
    difficulty: 'NORMAL',
  ),
  _ScenarioMeta(
    id: 'scenario_002',
    assetPath: 'assets/scenarios/scenario_002.json',
    title: 'Relay Hunt',
    description: '3 vs 7 — destroy all enemies. Keep your relay alive.',
    difficulty: 'HARD',
    prerequisiteId: 'scenario_001',
  ),
  _ScenarioMeta(
    id: 'scenario_003',
    assetPath: 'assets/scenarios/scenario_003.json',
    title: 'Holding Action',
    description: '4 vs 9 — survive for 2 minutes.',
    difficulty: 'BRUTAL',
    prerequisiteId: 'scenario_002',
  ),
  _ScenarioMeta(
    id: 'scenario_004',
    assetPath: 'assets/scenarios/scenario_004.json',
    title: 'Ambush at the Gap',
    description: '3 vs 8 — pincer attack. Destroy the enemy flagship.',
    difficulty: 'HARD',
    prerequisiteId: 'scenario_001',
  ),
  _ScenarioMeta(
    id: 'scenario_005',
    assetPath: 'assets/scenarios/scenario_005.json',
    title: 'Last Stand',
    description: '6 vs 12 — survive for 4 minutes.',
    difficulty: 'BRUTAL',
    prerequisiteId: 'scenario_004',
  ),
];

/// Pre-game screen that lets the player choose a scenario.
class ScenarioPickerScreen extends StatefulWidget {
  const ScenarioPickerScreen({super.key});

  @override
  State<ScenarioPickerScreen> createState() => _ScenarioPickerScreenState();
}

class _ScenarioPickerScreenState extends State<ScenarioPickerScreen> {
  Map<String, bool> _completed = {};

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final completed = <String, bool>{};
    for (final s in _scenarios) {
      completed[s.id] = prefs.getBool('completed_${s.id}') ?? false;
    }
    if (mounted) setState(() => _completed = completed);
  }

  bool _isUnlocked(_ScenarioMeta meta) {
    if (meta.prerequisiteId == null) return true;
    return _completed[meta.prerequisiteId!] ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: SingleChildScrollView(
        child: Center(
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
              ..._scenarios.map((s) => _ScenarioCard(
                    meta: s,
                    unlocked: _isUnlocked(s),
                    completed: _completed[s.id] ?? false,
                    onTap: () async {
                      await Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => DeploymentScreen(
                            scenarioId: s.id,
                            scenarioAssetPath: s.assetPath,
                          ),
                        ),
                      );
                      _loadProgress();
                    },
                  )),
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
      ),
    );
  }
}

class _ScenarioCard extends StatelessWidget {
  final _ScenarioMeta meta;
  final bool unlocked;
  final bool completed;
  final VoidCallback onTap;

  const _ScenarioCard({
    required this.meta,
    required this.unlocked,
    required this.completed,
    required this.onTap,
  });

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
        onTap: unlocked ? onTap : null,
        child: Opacity(
          opacity: unlocked ? 1.0 : 0.45,
          child: Container(
            width: 420,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(
                color: unlocked ? Colors.white12 : Colors.white.withAlpha(20),
              ),
              borderRadius: BorderRadius.circular(6),
              color: Colors.white.withAlpha(8),
            ),
            child: Row(
              children: [
                if (!unlocked)
                  const Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: Icon(Icons.lock_outline,
                        color: Colors.white30, size: 20),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        meta.title,
                        style: TextStyle(
                          color: unlocked ? Colors.white : Colors.white38,
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: _difficultyColor.withAlpha(180)),
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
                    if (completed)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Icon(Icons.check_circle_outline,
                            color: Colors.greenAccent, size: 14),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
