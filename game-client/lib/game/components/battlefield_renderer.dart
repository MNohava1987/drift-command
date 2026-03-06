import 'dart:math' as math;
import 'dart:ui';
import 'package:flame/components.dart';

import '../../core/models/ship_data.dart';
import '../../core/models/battle_state.dart';
import '../../data/ships/ship_definitions.dart';
import '../battle_game.dart';

/// Seconds of velocity projection drawn ahead of each ship.
const double kTrajectorySeconds = 8.0;

/// In-game "sensor speed" — units per second. Controls how stale enemy data looks.
const double kSensorSpeed = 400.0;

class _Star {
  final Vector2 position;
  final double radius;
  final int alpha;
  final Color color;

  const _Star({
    required this.position,
    required this.radius,
    required this.alpha,
    required this.color,
  });
}

/// Renders the game world onto the Flame canvas.
///
/// Owns the world→canvas transform, including zoom. All game logic uses world
/// coordinates; this component converts them to screen pixels.
class BattlefieldRenderer extends Component {
  static const double kWorldWidth = 1000.0;
  static const double kWorldHeight = 600.0;

  static const int _playerBase = 0xFF4A90D9;
  static const int _playerFlagship = 0xFF74B4FF;
  static const int _playerRelay = 0xFF6A9AC8;
  static const int _enemyBase = 0xFFD94A4A;
  static const int _enemyFlagship = 0xFFFF7474;
  static const int _enemyRelay = 0xFFC46A6A;

  final BattleGame game;

  // Base letterbox transform (screen-fitted)
  double _scale = 1.0;
  double _offX = 0.0;
  double _offY = 0.0;

  // Zoom (1.0 = default, centered on world center)
  double _zoom = 1.0;

  late List<_Star> _stars;

  BattlefieldRenderer(this.game);

  // ── Transform helpers ──────────────────────────────────────────────────────

  double get _es => _scale * _zoom;
  double get _eox => (kWorldWidth / 2) * _scale * (1 - _zoom) + _offX;
  double get _eoy => (kWorldHeight / 2) * _scale * (1 - _zoom) + _offY;

  Vector2 worldToCanvas(Vector2 worldPos) =>
      Vector2(worldPos.x * _es + _eox, worldPos.y * _es + _eoy);

  Vector2 canvasToWorld(Vector2 canvasPos) =>
      Vector2((canvasPos.x - _eox) / _es, (canvasPos.y - _eoy) / _es);

  // ── Zoom ──────────────────────────────────────────────────────────────────

  void adjustZoom(double factor) {
    _zoom = (_zoom * factor).clamp(0.4, 4.0);
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  Future<void> onLoad() async {
    final rng = math.Random(42);
    _stars = [];

    // Layer 1: 80 dim white stars
    for (var i = 0; i < 80; i++) {
      _stars.add(_Star(
        position: Vector2(rng.nextDouble() * kWorldWidth, rng.nextDouble() * kWorldHeight),
        radius: 0.5,
        alpha: 80,
        color: const Color(0xFFFFFFFF),
      ));
    }

    // Layer 2: 50 medium stars with slight blue/yellow tints
    for (var i = 0; i < 50; i++) {
      final tint = i % 2 == 0 ? const Color(0xFFCCDDFF) : const Color(0xFFFFFACC);
      _stars.add(_Star(
        position: Vector2(rng.nextDouble() * kWorldWidth, rng.nextDouble() * kWorldHeight),
        radius: 0.8,
        alpha: 140,
        color: tint,
      ));
    }

    // Layer 3: 20 bright varied-color stars
    const brightColors = [
      Color(0xFFFFFFFF), Color(0xFFAADDFF), Color(0xFFFFEEAA),
      Color(0xFFFFCCAA), Color(0xFFCCFFDD),
    ];
    for (var i = 0; i < 20; i++) {
      _stars.add(_Star(
        position: Vector2(rng.nextDouble() * kWorldWidth, rng.nextDouble() * kWorldHeight),
        radius: 1.3,
        alpha: 220,
        color: brightColors[i % brightColors.length],
      ));
    }
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _scale = math.min(size.x / kWorldWidth, size.y / kWorldHeight);
    _offX = (size.x - kWorldWidth * _scale) / 2;
    _offY = (size.y - kWorldHeight * _scale) / 2;
  }

  // ── Render ────────────────────────────────────────────────────────────────

  @override
  void render(Canvas canvas) {
    final state = game.battleStateOrNull;
    if (state == null) return;
    _drawBackground(canvas);
    _drawTacticalGrid(canvas);
    _drawCommandChainLines(canvas, state);
    _drawTrajectories(canvas, state);
    _drawSensorGhosts(canvas, state);
    _drawOrderLines(canvas, state);
    _drawShips(canvas, state);
    _drawParticles(canvas);
    _drawTransitPulses(canvas);
  }

  // ── Background ────────────────────────────────────────────────────────────

  void _drawBackground(Canvas canvas) {
    canvas.drawRect(
      Rect.fromLTWH(_offX, _offY, kWorldWidth * _scale, kWorldHeight * _scale),
      Paint()..color = const Color(0xFF0A0A18),
    );
    for (final star in _stars) {
      final c = worldToCanvas(star.position);
      canvas.drawCircle(
        Offset(c.x, c.y),
        star.radius,
        Paint()..color = star.color.withAlpha(star.alpha),
      );
    }
    canvas.drawRect(
      Rect.fromLTWH(_offX, _offY, kWorldWidth * _scale, kWorldHeight * _scale),
      Paint()
        ..color = const Color(0xFF223355)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  // ── Tactical grid ─────────────────────────────────────────────────────────

  void _drawTacticalGrid(Canvas canvas) {
    final gridPaint = Paint()
      ..color = const Color(0x0A4488FF)
      ..strokeWidth = 0.5;

    const gridStep = 100.0;

    // Vertical lines
    var wx = 0.0;
    while (wx <= kWorldWidth) {
      final top = worldToCanvas(Vector2(wx, 0));
      final bot = worldToCanvas(Vector2(wx, kWorldHeight));
      canvas.drawLine(Offset(top.x, top.y), Offset(bot.x, bot.y), gridPaint);
      wx += gridStep;
    }

    // Horizontal lines
    var wy = 0.0;
    while (wy <= kWorldHeight) {
      final left = worldToCanvas(Vector2(0, wy));
      final right = worldToCanvas(Vector2(kWorldWidth, wy));
      canvas.drawLine(Offset(left.x, left.y), Offset(right.x, right.y), gridPaint);
      wy += gridStep;
    }
  }

  // ── Trajectory projection ─────────────────────────────────────────────────

  void _drawTrajectories(Canvas canvas, BattleState state) {
    for (final ship in state.ships.values) {
      if (!ship.isAlive) continue;
      if (ship.velocity.length < 2.0) continue;

      final isPlayer = ship.factionId == state.playerFactionId;
      final from = worldToCanvas(ship.position);
      final projectedWorld = ship.position + ship.velocity * kTrajectorySeconds;
      final to = worldToCanvas(projectedWorld);

      final paint = Paint()
        ..color = (isPlayer
                ? const Color(0xFF4A90D9)
                : const Color(0xFFD94A4A))
            .withAlpha(isPlayer ? 100 : 60)
        ..strokeWidth = 1.0;

      _drawDashedLine(
        canvas,
        Offset(from.x, from.y),
        Offset(to.x, to.y),
        paint,
        dashLength: 4.0,
        gapLength: 5.0,
      );

      _drawArrow(canvas, from, to, paint);
    }
  }

  void _drawArrow(Canvas canvas, Vector2 from, Vector2 to, Paint paint) {
    final dx = to.x - from.x;
    final dy = to.y - from.y;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len < 10) return;
    final ux = dx / len;
    final uy = dy / len;
    const arrowLen = 6.0;
    const arrowAngle = 0.5;
    canvas.drawLine(
      Offset(to.x, to.y),
      Offset(
        to.x - arrowLen * (ux * math.cos(arrowAngle) - uy * math.sin(arrowAngle)),
        to.y - arrowLen * (ux * math.sin(arrowAngle) + uy * math.cos(arrowAngle)),
      ),
      paint,
    );
    canvas.drawLine(
      Offset(to.x, to.y),
      Offset(
        to.x - arrowLen * (ux * math.cos(-arrowAngle) - uy * math.sin(-arrowAngle)),
        to.y - arrowLen * (ux * math.sin(-arrowAngle) + uy * math.cos(-arrowAngle)),
      ),
      paint,
    );
  }

  // ── Sensor ghost ─────────────────────────────────────────────────────────

  void _drawSensorGhosts(Canvas canvas, BattleState state) {
    final playerTopology = state.topologies[state.playerFactionId];
    final flagshipId = playerTopology?.flagship.shipInstanceId;
    final playerFlagship = flagshipId != null ? state.ships[flagshipId] : null;
    if (playerFlagship == null) return;

    for (final ship in state.ships.values) {
      if (!ship.isAlive) continue;
      if (ship.factionId == state.playerFactionId) continue;

      final dist = playerFlagship.position.distanceTo(ship.position);
      final delay = dist / kSensorSpeed;
      if (delay < 0.5) continue;

      final ghostPos = ship.position - ship.velocity * delay;
      final ghostCanvas = worldToCanvas(ghostPos);
      final actualCanvas = worldToCanvas(ship.position);
      final role = _roleForShip(ship, state);
      final radius = _radiusForRole(role) * _es;

      canvas.drawCircle(
        Offset(ghostCanvas.x, ghostCanvas.y),
        radius,
        Paint()
          ..color = const Color(0xFFD94A4A).withAlpha(35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );

      _drawDashedLine(
        canvas,
        Offset(ghostCanvas.x, ghostCanvas.y),
        Offset(actualCanvas.x, actualCanvas.y),
        Paint()
          ..color = const Color(0xFFD94A4A).withAlpha(50)
          ..strokeWidth = 0.8,
        dashLength: 3.0,
        gapLength: 3.0,
      );
    }
  }

  // ── Ships ─────────────────────────────────────────────────────────────────

  void _drawShips(Canvas canvas, BattleState state) {
    final selectedShip = game.selectedShipState;
    for (final ship in state.ships.values) {
      if (!ship.isAlive) continue;
      _drawShip(canvas, ship, state, selected: ship == selectedShip);
    }
  }

  void _drawShip(
    Canvas canvas,
    ShipState ship,
    BattleState state, {
    required bool selected,
  }) {
    final role = _roleForShip(ship, state);
    final color = _colorForShip(ship, state, role);
    final radius = _radiusForRole(role) * _es;
    final center = worldToCanvas(ship.position);
    final co = Offset(center.x, center.y);
    final isPlayer = ship.factionId == state.playerFactionId;

    // Selection ring
    if (selected) {
      final ringColor = isPlayer
          ? (ship.shipMode == ShipMode.attack
              ? const Color(0xFFD94A3A)
              : const Color(0xFF4A90D9))
          : const Color(0xFFFFFFFF);
      canvas.drawCircle(
        co,
        radius + 5,
        Paint()
          ..color = ringColor.withAlpha(200)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      if (isPlayer) {
        final wr = _weaponRangeForRole(role);
        if (wr > 0) {
          canvas.drawCircle(
            co,
            wr * _es,
            Paint()
              ..color = color.withAlpha(50)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.0,
          );
        }
      }
    }

    // Glow: two soft circles before the ship shape
    final glowColor = isPlayer
        ? (ship.shipMode == ShipMode.attack
            ? const Color(0xFFD94A3A)
            : const Color(0xFF4A90D9))
        : color;
    canvas.drawCircle(co, radius + 10, Paint()..color = glowColor.withAlpha(15));
    canvas.drawCircle(co, radius + 5, Paint()..color = glowColor.withAlpha(30));

    // Directional ship shape
    canvas.save();
    canvas.translate(co.dx, co.dy);
    canvas.rotate(ship.heading);
    final shapePath = _shipPathForRole(role, radius / _radiusForRole(role));
    canvas.drawPath(shapePath, Paint()..color = color);
    canvas.restore();

    // Engine trail when moving fast
    if (ship.velocity.length > 8) {
      final speed = ship.velocity.length;
      final alpha = ((speed / 120.0).clamp(0.0, 1.0) * 180).toInt();
      final rearAngle = ship.heading + math.pi;
      final rearOffset = Offset(
        co.dx + math.cos(rearAngle) * (radius + 3),
        co.dy + math.sin(rearAngle) * (radius + 3),
      );
      final trailPath = Path()
        ..moveTo(rearOffset.dx + math.cos(rearAngle) * 5, rearOffset.dy + math.sin(rearAngle) * 5)
        ..lineTo(
          rearOffset.dx + math.cos(rearAngle + math.pi / 2) * 3,
          rearOffset.dy + math.sin(rearAngle + math.pi / 2) * 3,
        )
        ..lineTo(
          rearOffset.dx + math.cos(rearAngle - math.pi / 2) * 3,
          rearOffset.dy + math.sin(rearAngle - math.pi / 2) * 3,
        )
        ..close();
      canvas.drawPath(trailPath, Paint()..color = const Color(0xFFFF8800).withAlpha(alpha));
    }

    // Order-arrived flash ring
    final battleTime = game.battleStateOrNull?.battleTime ?? 0.0;
    if (battleTime < ship.orderFlashUntil) {
      final fade = ((ship.orderFlashUntil - battleTime) / 0.45).clamp(0.0, 1.0);
      canvas.drawCircle(
        co,
        radius + 8,
        Paint()
          ..color = const Color(0xFF00FFFF).withAlpha((fade * 220).toInt())
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );
    }

    // Ship label — floats above the shape
    _drawShipLabel(canvas, _labelForRole(role), co, radius, isPlayer);

    // Heading indicator
    {
      final headingDir = Vector2(math.cos(ship.heading), math.sin(ship.heading));
      final headingEnd = worldToCanvas(
        ship.position + headingDir * (_radiusForRole(role) + 20),
      );
      canvas.drawLine(
        co,
        Offset(headingEnd.x, headingEnd.y),
        Paint()
          ..color = const Color(0xFFB0D8FF).withAlpha(200)
          ..strokeWidth = 1.5,
      );
    }

    // Velocity vector
    if (ship.velocity.length > 1.0) {
      final velDir = ship.velocity.normalized();
      final lineEnd = worldToCanvas(
        ship.position + velDir * (_radiusForRole(role) + 14),
      );
      canvas.drawLine(
        co,
        Offset(lineEnd.x, lineEnd.y),
        Paint()
          ..color = color.withAlpha(220)
          ..strokeWidth = 1.5,
      );
    }

    // HP bar when damaged
    final data = kShipDefinitions[ship.dataId];
    if (data != null && ship.durability < data.maxDurability) {
      _drawHpBar(canvas, ship, data, center, radius);
    }
  }

  /// Returns ship path in local coords scaled to canvas size. Nose at +X.
  Path _shipPathForRole(ShipRole role, double scale) {
    final p = Path();
    switch (role) {
      case ShipRole.flagship:
        p.moveTo(14 * scale, 0);
        p.lineTo(6 * scale, -7 * scale);
        p.lineTo(-12 * scale, -5 * scale);
        p.lineTo(-14 * scale, 0);
        p.lineTo(-12 * scale, 5 * scale);
        p.lineTo(6 * scale, 7 * scale);
      case ShipRole.heavyLine:
        p.moveTo(11 * scale, 0);
        p.lineTo(4 * scale, -6 * scale);
        p.lineTo(-10 * scale, -6 * scale);
        p.lineTo(-11 * scale, 0);
        p.lineTo(-10 * scale, 6 * scale);
        p.lineTo(4 * scale, 6 * scale);
      case ShipRole.lightEscort:
        p.moveTo(7 * scale, 0);
        p.lineTo(-5 * scale, -4 * scale);
        p.lineTo(-6 * scale, 0);
        p.lineTo(-5 * scale, 4 * scale);
      case ShipRole.fastRaider:
        p.moveTo(9 * scale, 0);
        p.lineTo(-7 * scale, -2.5 * scale);
        p.lineTo(-5 * scale, 0);
        p.lineTo(-7 * scale, 2.5 * scale);
      case ShipRole.strikeCarrier:
        p.moveTo(10 * scale, 0);
        p.lineTo(3 * scale, -7 * scale);
        p.lineTo(-10 * scale, -7 * scale);
        p.lineTo(-12 * scale, 0);
        p.lineTo(-10 * scale, 7 * scale);
        p.lineTo(3 * scale, 7 * scale);
      case ShipRole.commandRelay:
        p.moveTo(0, -6 * scale);
        p.lineTo(5 * scale, 0);
        p.lineTo(0, 6 * scale);
        p.lineTo(-5 * scale, 0);
    }
    p.close();
    return p;
  }

  void _drawHpBar(
    Canvas canvas,
    ShipState ship,
    ShipData data,
    Vector2 center,
    double radius,
  ) {
    final barWidth = radius * 2;
    final frac = (ship.durability / data.maxDurability).clamp(0.0, 1.0);
    final barX = center.x - radius;
    final barY = center.y + radius + 3;
    canvas.drawRect(
      Rect.fromLTWH(barX, barY, barWidth, 3.0),
      Paint()..color = const Color(0x88FF0000),
    );
    canvas.drawRect(
      Rect.fromLTWH(barX, barY, barWidth * frac, 3.0),
      Paint()..color = const Color(0xFF00FF44),
    );
  }

  // ── Order lines ───────────────────────────────────────────────────────────

  void _drawOrderLines(Canvas canvas, BattleState state) {
    for (final ship in state.ships.values) {
      if (!ship.isAlive) continue;
      final sc = worldToCanvas(ship.position);
      final so = Offset(sc.x, sc.y);

      final active = ship.activeOrder;
      if (active?.targetPosition != null) {
        final tc = worldToCanvas(active!.targetPosition!);
        canvas.drawLine(
          so,
          Offset(tc.x, tc.y),
          Paint()
            ..color = const Color(0xFF00FFFF).withAlpha(160)
            ..strokeWidth = 1.2,
        );
      }

      final pendingPaint = Paint()
        ..color = const Color(0xFFFFDD44).withAlpha(160)
        ..strokeWidth = 1.0;
      for (final order in ship.pendingOrders) {
        if (order.targetPosition == null) continue;
        final tc = worldToCanvas(order.targetPosition!);
        _drawDashedLine(canvas, so, Offset(tc.x, tc.y), pendingPaint);
      }
    }
  }

  // ── Particles ─────────────────────────────────────────────────────────────

  void _drawParticles(Canvas canvas) {
    for (final p in game.particles) {
      final c = worldToCanvas(p.position);
      canvas.drawCircle(
        Offset(c.x, c.y),
        p.radius,
        Paint()..color = p.color.withAlpha((p.life * 200).toInt().clamp(0, 255)),
      );
    }
  }

  // ── Utilities ─────────────────────────────────────────────────────────────

  void _drawDashedLine(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint, {
    double dashLength = 5.0,
    double gapLength = 4.0,
  }) {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final dist = math.sqrt(dx * dx + dy * dy);
    if (dist == 0) return;
    final ux = dx / dist;
    final uy = dy / dist;
    var traveled = 0.0;
    var drawing = true;
    while (traveled < dist) {
      final segLen = drawing ? dashLength : gapLength;
      final next = math.min(traveled + segLen, dist);
      if (drawing) {
        canvas.drawLine(
          Offset(start.dx + ux * traveled, start.dy + uy * traveled),
          Offset(start.dx + ux * next, start.dy + uy * next),
          paint,
        );
      }
      traveled = next;
      drawing = !drawing;
    }
  }

  ShipRole _roleForShip(ShipState ship, BattleState state) {
    final topology = state.topologies[ship.factionId];
    if (topology != null) {
      for (final node in topology.nodes.values) {
        if (node.shipInstanceId == ship.instanceId) {
          return node.isRoot ? ShipRole.flagship : ShipRole.commandRelay;
        }
      }
    }
    return kShipDefinitions[ship.dataId]?.role ?? ShipRole.lightEscort;
  }

  Color _colorForShip(ShipState ship, BattleState state, ShipRole role) {
    final isPlayer = ship.factionId == state.playerFactionId;
    if (role == ShipRole.flagship) {
      return Color(isPlayer ? _playerFlagship : _enemyFlagship);
    }
    if (role == ShipRole.commandRelay) {
      return Color(isPlayer ? _playerRelay : _enemyRelay);
    }
    return Color(isPlayer ? _playerBase : _enemyBase);
  }

  double _radiusForRole(ShipRole role) => switch (role) {
        ShipRole.flagship => 12.0,
        ShipRole.heavyLine => 9.0,
        ShipRole.commandRelay || ShipRole.strikeCarrier => 6.0,
        ShipRole.lightEscort || ShipRole.fastRaider => 4.0,
      };

  double _weaponRangeForRole(ShipRole role) => switch (role) {
        ShipRole.flagship => 120.0,
        ShipRole.heavyLine => 150.0,
        ShipRole.strikeCarrier => 200.0,
        ShipRole.lightEscort => 100.0,
        ShipRole.fastRaider => 90.0,
        ShipRole.commandRelay => 80.0,
      };

  String _labelForRole(ShipRole role) => switch (role) {
        ShipRole.flagship => 'F',
        ShipRole.commandRelay => 'R',
        ShipRole.heavyLine => 'H',
        ShipRole.lightEscort => 'E',
        ShipRole.strikeCarrier => 'C',
        ShipRole.fastRaider => 'X',
      };

  void _drawShipLabel(
    Canvas canvas,
    String label,
    Offset center,
    double radius,
    bool isPlayer,
  ) {
    final fontSize = (radius * 1.1).clamp(6.0, 11.0);
    final pb = ParagraphBuilder(
      ParagraphStyle(textAlign: TextAlign.center),
    )
      ..pushStyle(TextStyle(
        color: const Color(0xFFFFFFFF),
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
      ))
      ..addText(label);
    final para = pb.build()
      ..layout(ParagraphConstraints(width: radius * 2));
    // Float label above the ship shape
    canvas.drawParagraph(
      para,
      Offset(center.dx - radius, center.dy - radius - 6 - para.height),
    );
  }

  // ── Command chain lines ────────────────────────────────────────────────────

  void _drawCommandChainLines(Canvas canvas, BattleState state) {
    final topology = state.topologies[state.playerFactionId];
    if (topology == null) return;
    final flagship = state.ships[topology.flagship.shipInstanceId];
    if (flagship == null || !flagship.isAlive) return;

    final flagshipC = worldToCanvas(flagship.position);
    final flagshipO = Offset(flagshipC.x, flagshipC.y);

    final flagshipToRelayPaint = Paint()
      ..color = const Color(0x26FFFFFF)
      ..strokeWidth = 1.0;
    final relayToCombatPaint = Paint()
      ..color = const Color(0x1AFFFFFF)
      ..strokeWidth = 0.8;

    for (final node in topology.nodes.values) {
      if (node.isRoot) continue;
      final relay = state.ships[node.shipInstanceId];
      if (relay == null || !relay.isAlive) continue;

      final relayC = worldToCanvas(relay.position);
      final relayO = Offset(relayC.x, relayC.y);
      canvas.drawLine(flagshipO, relayO, flagshipToRelayPaint);

      for (final combatId in node.assignedCombatShipIds) {
        final combat = state.ships[combatId];
        if (combat == null || !combat.isAlive) continue;
        final combatC = worldToCanvas(combat.position);
        canvas.drawLine(relayO, Offset(combatC.x, combatC.y), relayToCombatPaint);
      }
    }
  }

  // ── Transit pulses ─────────────────────────────────────────────────────────

  void _drawTransitPulses(Canvas canvas) {
    final paint = Paint()..color = const Color(0xFFFFDD44);
    for (final pulse in game.transitPulses) {
      final pos = worldToCanvas(pulse.currentPos);
      canvas.drawCircle(Offset(pos.x, pos.y), 3.0, paint);
    }
  }
}
