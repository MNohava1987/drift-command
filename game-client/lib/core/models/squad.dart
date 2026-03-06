import 'dart:math' as math;
import 'package:flame/components.dart';
import 'ship_data.dart';

enum EngagementMode { direct, engage, ghost }

enum SquadType {
  // M6 types
  flagship,
  lineDivision,
  raidPack,
  carrierStrike,
  escortScreen,
  // M7 types
  gunboatPack,
  interceptorScreen,
  flakLine,
  torpedoRun,
  cruiserDivision,
  ewFlight,
  carrierGroup,
  supportGroup,
  battlecruiserGroup,
  dreadnoughtGroup,
}

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
      // ── M6 types ──
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
      // ── M7 types ──
      case SquadType.gunboatPack:
        // 8 ships in a circle at r=40
        return List.generate(8, (i) {
          final angle = i * math.pi / 4;
          return Vector2(math.cos(angle) * 40, math.sin(angle) * 40);
        });
      case SquadType.interceptorScreen:
        // 6 ships in a ring at r=30
        return List.generate(6, (i) {
          final angle = i * math.pi / 3;
          return Vector2(math.cos(angle) * 30, math.sin(angle) * 30);
        });
      case SquadType.flakLine:
        return [Vector2(-30, 0), Vector2(0, 0), Vector2(30, 0)];
      case SquadType.torpedoRun:
        // Arrowhead: leader at front, 2 flankers behind, one trailing
        return [
          Vector2(0, 0),
          Vector2(-25, -20),
          Vector2(-25, 20),
          Vector2(-50, 0),
        ];
      case SquadType.cruiserDivision:
        return [Vector2(-20, 0), Vector2(20, 0)];
      case SquadType.ewFlight:
        return [Vector2(0, -25), Vector2(0, 25)];
      case SquadType.carrierGroup:
        return [Vector2(0, -30), Vector2(0, 30)];
      case SquadType.supportGroup:
        return [Vector2(0, -25), Vector2(0, 25)];
      case SquadType.battlecruiserGroup:
        return [Vector2.zero()];
      case SquadType.dreadnoughtGroup:
        return [Vector2.zero()];
    }
  }

  static List<String> shipDataIds(SquadType type) {
    switch (type) {
      // ── M6 types (updated hull IDs) ──
      case SquadType.flagship:
        return ['flagship'];
      case SquadType.lineDivision:
        return ['heavy_cruiser', 'heavy_cruiser'];
      case SquadType.raidPack:
        return List.filled(6, 'gunboat');
      case SquadType.carrierStrike:
        return ['strike_carrier', 'interceptor', 'interceptor'];
      case SquadType.escortScreen:
        return List.filled(5, 'interceptor');
      // ── M7 types ──
      case SquadType.gunboatPack:
        return List.filled(8, 'gunboat');
      case SquadType.interceptorScreen:
        return List.filled(6, 'interceptor');
      case SquadType.flakLine:
        return List.filled(3, 'flak_frigate');
      case SquadType.torpedoRun:
        return List.filled(4, 'destroyer');
      case SquadType.cruiserDivision:
        return ['heavy_cruiser', 'heavy_cruiser'];
      case SquadType.ewFlight:
        return ['ew_cruiser', 'ew_cruiser'];
      case SquadType.carrierGroup:
        return ['strike_carrier', 'strike_carrier'];
      case SquadType.supportGroup:
        return ['repair_tender', 'repair_tender'];
      case SquadType.battlecruiserGroup:
        return ['battlecruiser'];
      case SquadType.dreadnoughtGroup:
        return ['dreadnought'];
    }
  }

  static int cost(SquadType type) => switch (type) {
        SquadType.flagship => 0,
        SquadType.raidPack => 2,
        SquadType.escortScreen => 3,
        SquadType.lineDivision => 4,
        SquadType.carrierStrike => 5,
        // M7 costs
        SquadType.gunboatPack => 1,
        SquadType.interceptorScreen => 1,
        SquadType.flakLine => 2,
        SquadType.torpedoRun => 3,
        SquadType.cruiserDivision => 3,
        SquadType.ewFlight => 3,
        SquadType.carrierGroup => 4,
        SquadType.supportGroup => 4,
        SquadType.battlecruiserGroup => 5,
        SquadType.dreadnoughtGroup => 7,
      };
}
