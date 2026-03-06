import 'package:flame/components.dart';

/// The role that defines a ship's tactical identity and behavior profile.
enum ShipRole {
  flagship,
  commandRelay,
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
  commandSource,
  commandRelay,
  directFire,
  missile,
  pointDefense,
  screening,
  flanking,
}

/// Static ship configuration — these are the design-time stats for a ship role.
/// Think of this as the "class definition" or ScriptableObject equivalent.
class ShipData {
  final String id;
  final String displayName;
  final ShipRole role;
  final MassClass massClass;
  final double maxAcceleration;       // units/sec²
  final double turnRate;              // radians/sec
  final double commandLatencyMod;     // multiplier on base propagation delay (>1 = slower)
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
    required this.commandLatencyMod,
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
  final String dataId;        // references ShipData.id
  final int factionId;

  Vector2 position;
  Vector2 velocity;
  double heading;             // radians, 0 = right / east
  double durability;
  bool isAlive;

  String? assignedCommandNodeId;   // which command ship this unit reports to
  List<Order> pendingOrders;
  Order? activeOrder;              // order currently being executed
  Doctrine activeDoctrine;
  double orderFlashUntil;          // battle time until which to draw "order arrived" ring

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
    this.assignedCommandNodeId,
    List<Order>? pendingOrders,
    this.activeDoctrine = Doctrine.hold,
  })  : velocity = Vector2.zero(),
        isAlive = true,
        pendingOrders = pendingOrders ?? [],
        orderFlashUntil = -1.0;
}

/// An order issued to a ship, carrying the time it was created and
/// when it is expected to arrive at the receiving ship.
class Order {
  final OrderType type;
  final double issuedAt;        // battle time in seconds when order was issued
  final double arrivesAt;       // battle time when order reaches destination
  final Vector2? targetPosition;
  final String? targetShipId;
  final double targetSpeedFraction; // 0.25 slow / 0.5 medium / 1.0 fast

  const Order({
    required this.type,
    required this.issuedAt,
    required this.arrivesAt,
    this.targetPosition,
    this.targetShipId,
    this.targetSpeedFraction = 0.5,
  });

  bool isReady(double currentTime) => currentTime >= arrivesAt;
}

enum OrderType {
  moveTo,
  attackTarget,
  screen,
  hold,
  retreat,
  relay,
}

/// Persistent posture toggle set by the player per ship.
enum ShipMode { defensive, attack }

/// Fallback behavior when a ship is disconnected from its command chain.
enum Doctrine {
  hold,       // maintain position and course
  engage,     // attack nearest enemy in range
  retreat,    // move away from enemy
  screen,     // orbit nearest friendly capital ship
}
