import 'package:flame/components.dart';

/// The role that defines a ship's tactical identity and behavior profile.
enum ShipRole {
  flagship,
  heavyLine,
  lightEscort,
  strikeCarrier,
  fastRaider,
}

/// Determines how quickly a ship responds to thrust and turn commands.
enum MassClass {
  light,   // fast raider, light escort
  medium,  // command relay, strike carrier
  heavy,   // heavy line ship
  capital, // flagship
}

/// Tactical tags used by the AI and combat resolution system.
enum RoleTag {
  directFire,
  missile,
  pointDefense,
  screening,
  flanking,
}

/// Static ship configuration — design-time stats for a ship role.
class ShipData {
  final String id;
  final String displayName;
  final ShipRole role;
  final MassClass massClass;
  final double maxAcceleration;   // units/sec²
  final double turnRate;          // radians/sec
  final double sensorRange;
  final double weaponRange;
  final double maxDurability;
  final List<RoleTag> roleTags;

  const ShipData({
    required this.id,
    required this.displayName,
    required this.role,
    required this.massClass,
    required this.maxAcceleration,
    required this.turnRate,
    required this.sensorRange,
    required this.weaponRange,
    required this.maxDurability,
    required this.roleTags,
  });
}

/// Runtime state for a ship instance during a battle.
/// Mutable, updated each simulation tick.
class ShipState {
  final String instanceId;
  final String dataId;      // references ShipData.id
  final int factionId;
  String? squadId;

  Vector2 position;
  Vector2 velocity;
  double heading;           // radians, 0 = right / east
  double durability;
  bool isAlive;

  Order? activeOrder;       // order currently being executed
  Doctrine activeDoctrine;
  double orderFlashUntil;   // battle time until which to draw "order arrived" ring

  ShipMode shipMode = ShipMode.defensive;
  Vector2 thrustVector = Vector2.zero();
  double lastHitAt = -1.0;

  ShipState({
    required this.instanceId,
    required this.dataId,
    required this.factionId,
    required this.position,
    required this.heading,
    required this.durability,
    this.squadId,
    this.activeDoctrine = Doctrine.hold,
  })  : velocity = Vector2.zero(),
        isAlive = true,
        orderFlashUntil = -1.0;
}

/// An order issued to a ship. Immediate — no propagation delay.
class Order {
  final OrderType type;
  final Vector2? targetPosition;
  final String? targetShipId;
  final double targetSpeedFraction; // 0.25 slow / 0.5 medium / 1.0 fast

  const Order({
    required this.type,
    this.targetPosition,
    this.targetShipId,
    this.targetSpeedFraction = 0.5,
  });
}

enum OrderType {
  moveTo,
  attackTarget,
  hold,
  retreat,
}

/// Persistent posture toggle set by the player per ship.
enum ShipMode { defensive, attack }

/// Fallback behavior when a ship has no active order.
enum Doctrine {
  hold,     // maintain position and course
  engage,   // attack nearest enemy in range
  retreat,  // move away from enemy
  screen,   // orbit nearest friendly flagship
}
