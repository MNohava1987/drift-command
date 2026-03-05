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

  late List<Vector2> _stars;

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
    _stars = List.generate(
      150,
      (_) => Vector2(
        rng.nextDouble() * kWorldWidth,
        rng.nextDouble() * kWorldHeight,
      ),
    );
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
    _drawTrajectories(canvas, state);
    _drawSensorGhosts(canvas, state);
    _drawOrderLines(canvas, state);
    _drawShips(canvas, state);
  }

  // ── Background ────────────────────────────────────────────────────────────

  void _drawBackground(Canvas canvas) {
    canvas.drawRect(
      Rect.fromLTWH(_offX, _offY, kWorldWidth * _scale, kWorldHeight * _scale),
      Paint()..color = const Color(0xFF0A0A18),
    );
    final starPaint = Paint()..color = const Color(0xAAFFFFFF);
    for (final star in _stars) {
      final c = worldToCanvas(star);
      canvas.drawCircle(Offset(c.x, c.y), 0.8, starPaint);
    }
    canvas.drawRect(
      Rect.fromLTWH(_offX, _offY, kWorldWidth * _scale, kWorldHeight * _scale),
      Paint()
        ..color = const Color(0xFF223355)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  // ── Trajectory projection ─────────────────────────────────────────────────

  void _drawTrajectories(Canvas canvas, BattleState state) {
    for (final ship in state.ships.values) {
      if (!ship.isAlive) continue;
      if (ship.velocity.length < 2.0) continue; // skip near-stationary

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

      // Arrowhead at tip
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

  // ── Sensor ghost (enemy position delay) ───────────────────────────────────

  void _drawSensorGhosts(Canvas canvas, BattleState state) {
    // Reference point for sensor delay: player flagship position
    final playerTopology = state.topologies[state.playerFactionId];
    final flagshipId = playerTopology?.flagship.shipInstanceId;
    final playerFlagship =
        flagshipId != null ? state.ships[flagshipId] : null;
    if (playerFlagship == null) return;

    for (final ship in state.ships.values) {
      if (!ship.isAlive) continue;
      if (ship.factionId == state.playerFactionId) continue; // only enemies

      final dist = playerFlagship.position.distanceTo(ship.position);
      final delay = dist / kSensorSpeed;
      if (delay < 0.5) continue; // too close to matter

      // Ghost = where the enemy appeared to be [delay] seconds ago
      final ghostPos = ship.position - ship.velocity * delay;
      final ghostCanvas = worldToCanvas(ghostPos);
      final actualCanvas = worldToCanvas(ship.position);
      final role = _roleForShip(ship, state);
      final radius = _radiusForRole(role) * _es;

      // Ghost circle (faint)
      canvas.drawCircle(
        Offset(ghostCanvas.x, ghostCanvas.y),
        radius,
        Paint()
          ..color = const Color(0xFFD94A4A).withAlpha(35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );

      // Dotted line from ghost to actual position (the "where it probably is now")
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

    if (selected) {
      canvas.drawCircle(
        co,
        radius + 5,
        Paint()
          ..color = const Color(0xFFFFFFFF).withAlpha(200)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      if (ship.factionId == state.playerFactionId) {
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

    canvas.drawCircle(co, radius, Paint()..color = color);

    // Velocity heading line (direction of travel)
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

      // Active order — cyan solid
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

      // Pending orders — yellow dashed
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
}
