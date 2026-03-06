import 'dart:math' as math;
import 'package:flame/components.dart';
import 'ship_data.dart';

enum EngagementMode { direct, engage, ghost }

enum SquadType { flagship, lineDivision, raidPack, carrierStrike, escortScreen }

class SquadState {
  final String squadId;
  final SquadType type;
  final int factionId;

  Vector2 centroid;
  double heading;
  Vector2 velocity;
  EngagementMode engagementMode;
  Order? activeOrder;
  double orderFlashUntil;
  final List<String> shipInstanceIds;

  SquadState({
    required this.squadId,
    required this.type,
    required this.factionId,
    required this.centroid,
    required this.heading,
    required this.shipInstanceIds,
    this.engagementMode = EngagementMode.engage,
    Vector2? velocity,
    this.activeOrder,
    this.orderFlashUntil = -1.0,
  }) : velocity = velocity ?? Vector2.zero();

  static List<Vector2> formationOffsets(SquadType type) {
    switch (type) {
      case SquadType.flagship:
        return [Vector2.zero()];
      case SquadType.lineDivision:
        return [Vector2(-20, 0), Vector2(20, 0)];
      case SquadType.raidPack:
        return List.generate(6, (i) {
          final angle = i * math.pi / 3;
          return Vector2(math.cos(angle) * 30, math.sin(angle) * 30);
        });
      case SquadType.carrierStrike:
        return [Vector2(0, 0), Vector2(-40, -20), Vector2(-40, 20)];
      case SquadType.escortScreen:
        return [
          Vector2(0, 0),
          Vector2(-25, -30),
          Vector2(25, -30),
          Vector2(-50, -15),
          Vector2(50, -15),
        ];
    }
  }

  static List<String> shipDataIds(SquadType type) {
    switch (type) {
      case SquadType.flagship:
        return ['flagship'];
      case SquadType.lineDivision:
        return ['heavy_line', 'heavy_line'];
      case SquadType.raidPack:
        return List.filled(6, 'fast_raider');
      case SquadType.carrierStrike:
        return ['strike_carrier', 'light_escort', 'light_escort'];
      case SquadType.escortScreen:
        return List.filled(5, 'light_escort');
    }
  }

  static int cost(SquadType type) => switch (type) {
        SquadType.flagship => 0,
        SquadType.raidPack => 2,
        SquadType.escortScreen => 3,
        SquadType.lineDivision => 4,
        SquadType.carrierStrike => 5,
      };
}
