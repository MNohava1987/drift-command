import 'dart:math' as math;
import 'dart:ui';
import 'package:flame/components.dart';

import '../../core/models/ship_data.dart';
import '../../core/models/battle_state.dart';
import '../../data/ships/ship_definitions.dart';
import '../battle_game.dart';

/// Renders the game world onto the Flame canvas.
///
/// Owns the world→canvas transform. All game logic uses world coordinates;
/// this component converts them to screen pixels via a letterboxed scale.
class BattlefieldRenderer extends Component {
  static const double kWorldWidth = 1000.0;
  static const double kWorldHeight = 600.0;

  // Colors
  static const int _playerBase = 0xFF4A90D9;
  static const int _playerFlagship = 0xFF74B4FF;
  static const int _playerRelay = 0xFF6A9AC8;
  static const int _enemyBase = 0xFFD94A4A;
  static const int _enemyFlagship = 0xFFFF7474;
  static const int _enemyRelay = 0xFFC46A6A;

  final BattleGame game;

  double _scale = 1.0;
  double _offX = 0.0;
  double _offY = 0.0;
  late List<Vector2> _stars;

  BattlefieldRenderer(this.game);

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

  /// Convert a world-space position to canvas pixels.
  Vector2 worldToCanvas(Vector2 worldPos) {
    return Vector2(worldPos.x * _scale + _offX, worldPos.y * _scale + _offY);
  }

  /// Convert a canvas-space position to world units.
  Vector2 canvasToWorld(Vector2 canvasPos) {
    return Vector2(
      (canvasPos.x - _offX) / _scale,
      (canvasPos.y - _offY) / _scale,
    );
  }

  @override
  void render(Canvas canvas) {
    final state = game.battleStateOrNull;
    if (state == null) return;
    _drawBackground(canvas);
    _drawShips(canvas, state);
    _drawOrderLines(canvas, state);
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
    final radius = _radiusForRole(role) * _scale;
    final center = worldToCanvas(ship.position);
    final co = Offset(center.x, center.y);

    if (selected) {
      canvas.drawCircle(
        co,
        radius + 4,
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
            wr * _scale,
            Paint()
              ..color = color.withAlpha(60)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.0,
          );
        }
      }
    }

    canvas.drawCircle(co, radius, Paint()..color = color);

    // Heading line
    final headingEnd = worldToCanvas(
      ship.position +
          Vector2(
            math.cos(ship.heading) * (_radiusForRole(role) + 15),
            math.sin(ship.heading) * (_radiusForRole(role) + 15),
          ),
    );
    canvas.drawLine(
      co,
      Offset(headingEnd.x, headingEnd.y),
      Paint()
        ..color = color.withAlpha(200)
        ..strokeWidth = 1.5,
    );

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

      // Active order — cyan solid line
      final active = ship.activeOrder;
      if (active?.targetPosition != null) {
        final tc = worldToCanvas(active!.targetPosition!);
        canvas.drawLine(
          so,
          Offset(tc.x, tc.y),
          Paint()
            ..color = const Color(0xFF00FFFF)
            ..strokeWidth = 1.2,
        );
      }

      // Pending orders — yellow dashed lines
      final pendingPaint = Paint()
        ..color = const Color(0xFFFFDD44)
        ..strokeWidth = 1.0;
      for (final order in ship.pendingOrders) {
        if (order.targetPosition == null) continue;
        final tc = worldToCanvas(order.targetPosition!);
        _drawDashedLine(canvas, so, Offset(tc.x, tc.y), pendingPaint);
      }
    }
  }

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

  // ── Helpers ───────────────────────────────────────────────────────────────

  ShipRole _roleForShip(ShipState ship, BattleState state) {
    final topology = state.topologies[ship.factionId];
    if (topology != null) {
      for (final node in topology.nodes.values) {
        if (node.shipInstanceId == ship.instanceId) {
          return node.isRoot ? ShipRole.flagship : ShipRole.commandRelay;
        }
      }
    }
    final data = kShipDefinitions[ship.dataId];
    return data?.role ?? ShipRole.lightEscort;
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

  double _radiusForRole(ShipRole role) {
    return switch (role) {
      ShipRole.flagship => 12.0,
      ShipRole.heavyLine => 9.0,
      ShipRole.commandRelay || ShipRole.strikeCarrier => 6.0,
      ShipRole.lightEscort || ShipRole.fastRaider => 4.0,
    };
  }

  double _weaponRangeForRole(ShipRole role) {
    return switch (role) {
      ShipRole.flagship => 120.0,
      ShipRole.heavyLine => 150.0,
      ShipRole.strikeCarrier => 200.0,
      ShipRole.lightEscort => 100.0,
      ShipRole.fastRaider => 90.0,
      ShipRole.commandRelay => 80.0,
    };
  }
}
