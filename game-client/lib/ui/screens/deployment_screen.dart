import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../core/models/battle_state.dart';
import '../../core/models/ship_data.dart';
import '../../core/models/squad.dart';
import '../../core/services/scenario_loader.dart';
import '../../data/ships/ship_definitions.dart';
import 'game_screen.dart';

/// Pre-battle deployment screen.
///
/// Loads the scenario JSON to get the initial BattleState (enemy squads placed,
/// player flagship placed). The player spends budget to add more squads, sets
/// engagement modes and headings, then taps DEPLOY to launch the battle.
class DeploymentScreen extends StatefulWidget {
  final String scenarioAssetPath;
  final String scenarioId;

  const DeploymentScreen({
    super.key,
    required this.scenarioAssetPath,
    required this.scenarioId,
  });

  @override
  State<DeploymentScreen> createState() => _DeploymentScreenState();
}

class _DeploymentScreenState extends State<DeploymentScreen> {
  static const double kWorldWidth = 2000.0;
  static const double kWorldHeight = 1200.0;

  BattleState? _baseState; // loaded from JSON
  final List<_PlacedSquad> _placed = []; // player-placed squads (excluding flagship)
  String? _selectedPlacedId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadScenario();
  }

  Future<void> _loadScenario() async {
    final jsonStr = await rootBundle.loadString(widget.scenarioAssetPath);
    final jsonMap = jsonDecode(jsonStr) as Map<String, dynamic>;
    final state = ScenarioLoader.fromJson(jsonMap, kShipDefinitions);
    if (mounted) {
      setState(() {
        _baseState = state;
        _loading = false;
      });
    }
  }

  int get _budgetSpent =>
      _placed.fold(0, (sum, p) => sum + SquadState.cost(p.type));

  int get _budgetRemaining => (_baseState?.playerBudget ?? 0) - _budgetSpent;

  List<SquadType> get _availableTypes =>
      _baseState?.availableSquadTypes ?? [];

  void _addSquad(SquadType type) {
    if (_budgetRemaining < SquadState.cost(type)) return;
    final id = 'p_${type.name}_${DateTime.now().millisecondsSinceEpoch}';
    setState(() {
      _placed.add(_PlacedSquad(
        squadId: id,
        type: type,
        // Default position: left-center area, staggered
        position: Offset(300 + _placed.length * 60.0, 600),
        heading: 0,
        engagementMode: EngagementMode.engage,
      ));
      _selectedPlacedId = id;
    });
  }

  void _removeSelected() {
    if (_selectedPlacedId == null) return;
    setState(() {
      _placed.removeWhere((p) => p.squadId == _selectedPlacedId);
      _selectedPlacedId = null;
    });
  }

  void _setMode(EngagementMode mode) {
    setState(() {
      for (final p in _placed) {
        if (p.squadId == _selectedPlacedId) p.engagementMode = mode;
      }
    });
  }

  void _rotateHeading(double delta) {
    setState(() {
      for (final p in _placed) {
        if (p.squadId == _selectedPlacedId) {
          p.heading = (p.heading + delta) % (math.pi * 2);
        }
      }
    });
  }

  void _reset() {
    setState(() {
      _placed.clear();
      _selectedPlacedId = null;
    });
  }

  void _deploy() {
    final base = _baseState;
    if (base == null) return;

    // Merge placed squads into state
    final newSquads = Map<String, SquadState>.from(base.squads);
    final newShips = Map<String, ShipState>.from(base.ships);

    for (final placed in _placed) {
      final centroid = Vector2(placed.position.dx, placed.position.dy);
      final dataIds = SquadState.shipDataIds(placed.type);
      final offsets = SquadState.formationOffsets(placed.type);
      final instanceIds = <String>[];
      final cosH = math.cos(placed.heading);
      final sinH = math.sin(placed.heading);

      for (var i = 0; i < dataIds.length; i++) {
        final dataId = dataIds[i];
        final data = kShipDefinitions[dataId];
        if (data == null) continue;

        final offset = i < offsets.length ? offsets[i] : Vector2.zero();
        final worldPos = Vector2(
          centroid.x + offset.x * cosH - offset.y * sinH,
          centroid.y + offset.x * sinH + offset.y * cosH,
        );

        final instanceId = '${placed.squadId}_ship_$i';
        instanceIds.add(instanceId);

        newShips[instanceId] = ShipState(
          instanceId: instanceId,
          dataId: dataId,
          factionId: base.playerFactionId,
          position: worldPos,
          heading: placed.heading,
          durability: data.maxDurability,
          squadId: placed.squadId,
        );
      }

      newSquads[placed.squadId] = SquadState(
        squadId: placed.squadId,
        type: placed.type,
        factionId: base.playerFactionId,
        centroid: centroid,
        heading: placed.heading,
        shipInstanceIds: instanceIds,
        engagementMode: placed.engagementMode,
      );
    }

    final deployedState = BattleState(
      playerFactionId: base.playerFactionId,
      objectiveDescription: base.objectiveDescription,
      ships: newShips,
      squads: newSquads,
      playerBudget: base.playerBudget,
      availableSquadTypes: base.availableSquadTypes,
      playerFlagshipId: base.playerFlagshipId,
      enemyFlagshipId: base.enemyFlagshipId,
      winCondition: base.winCondition,
      factionPostures: base.factionPostures,
    );

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => GameScreen(
          scenarioId: widget.scenarioId,
          scenarioAssetPath: widget.scenarioAssetPath,
          initialState: deployedState,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0E1A),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF4A90D9))),
      );
    }

    final base = _baseState!;
    final selected = _placed.firstWhere(
      (p) => p.squadId == _selectedPlacedId,
      orElse: () => _PlacedSquad(
          squadId: '', type: SquadType.flagship, position: Offset.zero, heading: 0, engagementMode: EngagementMode.engage),
    );
    final hasSelected = _selectedPlacedId != null &&
        _placed.any((p) => p.squadId == _selectedPlacedId);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: Row(
        children: [
          // ── Canvas ──────────────────────────────────────────────────────
          Expanded(
            child: GestureDetector(
              onTapDown: (details) => _handleCanvasTap(details.localPosition),
              onPanUpdate: (details) => _handleDrag(details.localPosition),
              child: CustomPaint(
                painter: _DeploymentPainter(
                  base: base,
                  placed: _placed,
                  selectedId: _selectedPlacedId,
                ),
                child: Container(),
              ),
            ),
          ),
          // ── Sidebar ──────────────────────────────────────────────────────
          Container(
            width: 220,
            color: const Color(0xFF0D1220),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Budget
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('DEPLOYMENT',
                          style: TextStyle(
                              color: Color(0xFF4A90D9),
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2)),
                      const SizedBox(height: 8),
                      Text(
                        'Budget: $_budgetRemaining / ${base.playerBudget}',
                        style: TextStyle(
                            color: _budgetRemaining >= 0
                                ? Colors.white70
                                : Colors.red,
                            fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white12),
                // Squad type buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('ADD SQUAD',
                          style: TextStyle(
                              color: Colors.white38, fontSize: 10, letterSpacing: 2)),
                      const SizedBox(height: 8),
                      ..._availableTypes.map((type) {
                        final cost = SquadState.cost(type);
                        final canAfford = _budgetRemaining >= cost;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: _SidebarButton(
                            label: '${_squadLabel(type)}  [$cost]',
                            enabled: canAfford,
                            onTap: canAfford ? () => _addSquad(type) : null,
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                // Selected squad controls
                if (hasSelected) ...[
                  const Divider(color: Colors.white12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _squadLabel(selected.type),
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text('MODE',
                            style: TextStyle(
                                color: Colors.white38, fontSize: 10, letterSpacing: 2)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _ModeButton('D', EngagementMode.direct, selected.engagementMode,
                                () => _setMode(EngagementMode.direct)),
                            const SizedBox(width: 4),
                            _ModeButton('E', EngagementMode.engage, selected.engagementMode,
                                () => _setMode(EngagementMode.engage)),
                            const SizedBox(width: 4),
                            _ModeButton('G', EngagementMode.ghost, selected.engagementMode,
                                () => _setMode(EngagementMode.ghost)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text('HEADING',
                            style: TextStyle(
                                color: Colors.white38, fontSize: 10, letterSpacing: 2)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: _SidebarButton(
                                  label: '◄ -22°',
                                  enabled: true,
                                  onTap: () => _rotateHeading(-math.pi / 8)),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: _SidebarButton(
                                  label: '+22° ►',
                                  enabled: true,
                                  onTap: () => _rotateHeading(math.pi / 8)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        _SidebarButton(
                          label: 'REMOVE',
                          enabled: true,
                          color: const Color(0xFFD94A4A),
                          onTap: _removeSelected,
                        ),
                      ],
                    ),
                  ),
                ],
                const Spacer(),
                const Divider(color: Colors.white12),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SidebarButton(
                          label: 'RESET', enabled: true, onTap: _reset),
                      const SizedBox(height: 8),
                      _SidebarButton(
                        label: 'DEPLOY',
                        enabled: true,
                        color: const Color(0xFF4A90D9),
                        onTap: _deploy,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handleCanvasTap(Offset localPos) {
    // Select a placed squad
    final size = context.size;
    if (size == null) return;
    final worldPos = _canvasToWorld(localPos, size);

    for (final placed in _placed) {
      final dist =
          (placed.position - worldPos).distance;
      if (dist < 40) {
        setState(() => _selectedPlacedId = placed.squadId);
        return;
      }
    }
    // Tap empty space: move selected squad there
    if (_selectedPlacedId != null) {
      setState(() {
        for (final p in _placed) {
          if (p.squadId == _selectedPlacedId) p.position = worldPos;
        }
      });
    }
  }

  void _handleDrag(Offset localPos) {
    if (_selectedPlacedId == null) return;
    final size = context.size;
    if (size == null) return;
    final worldPos = _canvasToWorld(localPos, size);
    setState(() {
      for (final p in _placed) {
        if (p.squadId == _selectedPlacedId) p.position = worldPos;
      }
    });
  }

  Offset _canvasToWorld(Offset canvasPos, Size screenSize) {
    // Canvas occupies the screen minus the 220-wide sidebar
    final canvasWidth = screenSize.width - 220;
    final canvasHeight = screenSize.height;
    final scale =
        math.min(canvasWidth / kWorldWidth, canvasHeight / kWorldHeight);
    final offX = (canvasWidth - kWorldWidth * scale) / 2;
    final offY = (canvasHeight - kWorldHeight * scale) / 2;
    return Offset(
      (canvasPos.dx - offX) / scale,
      (canvasPos.dy - offY) / scale,
    );
  }
}

// ── Painter ────────────────────────────────────────────────────────────────────

class _DeploymentPainter extends CustomPainter {
  final BattleState base;
  final List<_PlacedSquad> placed;
  final String? selectedId;

  static const double kWorldWidth = 2000.0;
  static const double kWorldHeight = 1200.0;

  _DeploymentPainter(
      {required this.base, required this.placed, required this.selectedId});

  double _scale = 1.0;
  double _offX = 0.0;
  double _offY = 0.0;

  Offset _toCanvas(double wx, double wy) =>
      Offset(wx * _scale + _offX, wy * _scale + _offY);

  @override
  void paint(Canvas canvas, Size size) {
    _scale = math.min(size.width / kWorldWidth, size.height / kWorldHeight);
    _offX = (size.width - kWorldWidth * _scale) / 2;
    _offY = (size.height - kWorldHeight * _scale) / 2;

    // Background
    canvas.drawRect(
      Rect.fromLTWH(_offX, _offY, kWorldWidth * _scale, kWorldHeight * _scale),
      Paint()..color = const Color(0xFF0A0A18),
    );

    // Deployment zone divider (left half = player zone)
    canvas.drawLine(
      _toCanvas(kWorldWidth / 2, 0),
      _toCanvas(kWorldWidth / 2, kWorldHeight),
      Paint()
        ..color = const Color(0x22FFFFFF)
        ..strokeWidth = 1.0,
    );

    // Grid
    final gridPaint = Paint()
      ..color = const Color(0x0A4488FF)
      ..strokeWidth = 0.5;
    for (var wx = 0.0; wx <= kWorldWidth; wx += 100) {
      final top = _toCanvas(wx, 0);
      final bot = _toCanvas(wx, kWorldHeight);
      canvas.drawLine(top, bot, gridPaint);
    }
    for (var wy = 0.0; wy <= kWorldHeight; wy += 100) {
      final l = _toCanvas(0, wy);
      final r = _toCanvas(kWorldWidth, wy);
      canvas.drawLine(l, r, gridPaint);
    }

    // Enemy squads — faint red outlines only
    for (final sq in base.enemySquads) {
      final c = _toCanvas(sq.centroid.x, sq.centroid.y);
      canvas.drawCircle(
        c,
        20 * _scale,
        Paint()
          ..color = const Color(0x33D94A4A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );
      _drawLabel(canvas, _squadTypeLabel(sq.type), c);
    }

    // Player flagship from base state
    for (final sq in base.playerSquads) {
      final c = _toCanvas(sq.centroid.x, sq.centroid.y);
      canvas.drawCircle(
        c,
        20 * _scale,
        Paint()..color = const Color(0xFF4A90D9).withAlpha(180),
      );
      _drawLabel(canvas, 'FLAG', c);
    }

    // Player-placed squads
    for (final p in placed) {
      final c = _toCanvas(p.position.dx, p.position.dy);
      final isSelected = p.squadId == selectedId;
      canvas.drawCircle(
        c,
        18 * _scale,
        Paint()..color = const Color(0xFF4A90D9).withAlpha(isSelected ? 220 : 130),
      );
      if (isSelected) {
        canvas.drawCircle(
          c,
          22 * _scale,
          Paint()
            ..color = const Color(0xFFFFFFFF).withAlpha(180)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
      // Heading indicator
      final hx = c.dx + math.cos(p.heading) * 28 * _scale;
      final hy = c.dy + math.sin(p.heading) * 28 * _scale;
      canvas.drawLine(c, Offset(hx, hy),
          Paint()..color = Colors.white38..strokeWidth = 1.0);
      _drawLabel(canvas, _squadTypeLabel(p.type), c);
    }
  }

  void _drawLabel(Canvas canvas, String text, Offset center) {
    final pb = ui.ParagraphBuilder(ui.ParagraphStyle(textAlign: TextAlign.center))
      ..pushStyle(ui.TextStyle(
          color: const Color(0xFFFFFFFF), fontSize: 9.0 * _scale.clamp(0.5, 1.0)))
      ..addText(text);
    final para = pb.build()..layout(ui.ParagraphConstraints(width: 60));
    canvas.drawParagraph(
        para, Offset(center.dx - 30, center.dy - para.height / 2));
  }

  @override
  bool shouldRepaint(covariant _DeploymentPainter oldDelegate) => true;
}

// ── Helpers ────────────────────────────────────────────────────────────────────

class _PlacedSquad {
  final String squadId;
  final SquadType type;
  Offset position;
  double heading;
  EngagementMode engagementMode;

  _PlacedSquad({
    required this.squadId,
    required this.type,
    required this.position,
    required this.heading,
    required this.engagementMode,
  });
}

String _squadLabel(SquadType type) => switch (type) {
      SquadType.flagship => 'Flagship',
      SquadType.lineDivision => 'Line Division',
      SquadType.raidPack => 'Raid Pack',
      SquadType.carrierStrike => 'Carrier Strike',
      SquadType.escortScreen => 'Escort Screen',
    };

String _squadTypeLabel(SquadType type) => switch (type) {
      SquadType.flagship => 'FLAG',
      SquadType.lineDivision => 'LINE',
      SquadType.raidPack => 'RAID',
      SquadType.carrierStrike => 'CSTR',
      SquadType.escortScreen => 'ESCR',
    };

class _SidebarButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback? onTap;
  final Color? color;

  const _SidebarButton({
    required this.label,
    required this.enabled,
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? const Color(0xFF4A90D9);
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.35,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: c.withAlpha(180)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: c,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2)),
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String label;
  final EngagementMode mode;
  final EngagementMode current;
  final VoidCallback onTap;

  const _ModeButton(this.label, this.mode, this.current, this.onTap);

  @override
  Widget build(BuildContext context) {
    final active = mode == current;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFF4A90D9).withAlpha(80)
                : Colors.transparent,
            border: Border.all(
                color: active
                    ? const Color(0xFF4A90D9)
                    : Colors.white24),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: active ? const Color(0xFF4A90D9) : Colors.white38,
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}
