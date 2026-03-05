import 'package:flutter/material.dart';
import 'scenario_picker_screen.dart';

class _TutorialStep {
  final String title;
  final String body;
  final String visual; // ASCII diagram

  const _TutorialStep({
    required this.title,
    required this.body,
    required this.visual,
  });
}

const _steps = [
  _TutorialStep(
    title: 'Ships Have Momentum',
    body:
        'Ships do not teleport. They have velocity and mass. '
        'Thrust changes their vector gradually.\n\n'
        'A heavy capital ship going full speed needs hundreds of '
        'units to stop. If you commit to a direction, you are '
        'committed — physics does not negotiate.',
    visual:
        '  ──→  ──→  ──→  ──→  ──→\n'
        '  ship accelerates along vector\n\n'
        '  ──→  ─→  →  .          \n'
        '  braking: must start early',
  ),
  _TutorialStep(
    title: 'Speed Is a Choice',
    body:
        'Every order you issue has a speed: SLOW, MED, or FAST.\n\n'
        'SLOW: controllable, adjustable, long exposure.\n'
        'MED:  balanced. Good default.\n'
        'FAST: commits hard. You may overshoot. '
        'Lighter ships snap back. Heavy ones don\'t.',
    visual:
        '  SLOW  ─────────────────● stop\n'
        '  MED   ──────────●\n'
        '  FAST  ─────●──────────────→ overshoot',
  ),
  _TutorialStep(
    title: 'You See the Past',
    body:
        'Enemy positions on your display are delayed. '
        'The further away they are, the more stale the data.\n\n'
        'A faint ghost shows where the enemy appeared to be. '
        'The dotted line shows the projected gap to their '
        'estimated current position.\n\n'
        'If they changed course, you won\'t know until '
        'the new signal reaches you.',
    visual:
        '  ○ ·········· ●\n'
        '  ghost      actual\n'
        '  (sensor)   (projected)\n\n'
        '  distance = delay = uncertainty',
  ),
  _TutorialStep(
    title: 'Command Windows',
    body:
        'You cannot issue orders continuously. '
        'The CMD READY indicator tells you when your '
        'command pulse is open.\n\n'
        'When you issue an order, the window closes. '
        'It reopens after a duration based on tempo:\n\n'
        'DISTANT  →  15 seconds\n'
        'CONTACT  →  7 seconds\n'
        'ENGAGED  →  3 seconds',
    visual:
        '  [CMD READY]  ← issue order now\n'
        '       ↓\n'
        '  [CMD WAIT ]  ← window closed\n'
        '       ↓\n'
        '  [CMD READY]  ← next window opens',
  ),
  _TutorialStep(
    title: 'The Command Chain',
    body:
        'Your Flagship is the source of all orders. '
        'Orders travel through Command Relay ships to reach '
        'combat units — taking time proportional to distance.\n\n'
        'If a Relay ship is destroyed, the ships it commanded '
        'go ISOLATED. They execute their doctrine independently '
        'and stop receiving your orders.\n\n'
        'Protect your Relay. Destroy theirs.',
    visual:
        '  [Flagship] ──→ [Relay] ──→ [Heavy]\n'
        '                         ──→ [Escort]\n\n'
        '  Relay destroyed:\n'
        '  [Flagship]     [ISOLATED] ··· [Heavy]\n'
        '                             ··· [Escort]',
  ),
];

/// Five-step tutorial that teaches the core physics pillars.
class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  int _step = 0;

  void _next() {
    if (_step < _steps.length - 1) {
      setState(() => _step++);
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ScenarioPickerScreen()),
      );
    }
  }

  void _skip() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const ScenarioPickerScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_step];
    final isLast = _step == _steps.length - 1;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: SafeArea(
        child: Column(
          children: [
            // Progress dots
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_steps.length, (i) {
                  return Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == _step
                          ? const Color(0xFF4A90D9)
                          : Colors.white24,
                    ),
                  );
                }),
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    Text(
                      step.title.toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFF4A90D9),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      step.body,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white12),
                        borderRadius: BorderRadius.circular(6),
                        color: Colors.white.withAlpha(6),
                      ),
                      child: Text(
                        step.visual,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                          fontFamily: 'monospace',
                          height: 1.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Navigation
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: _skip,
                    child: const Text(
                      'SKIP',
                      style: TextStyle(
                        color: Colors.white30,
                        fontSize: 12,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _next,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFF4A90D9)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isLast ? 'BATTLE' : 'NEXT',
                        style: const TextStyle(
                          color: Color(0xFF4A90D9),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
