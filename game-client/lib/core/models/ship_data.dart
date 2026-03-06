import 'package:flame/components.dart';

/// The role that defines a ship's tactical identity and behavior profile.
enum ShipRole {
  // Tier 0 — Command
  flagship,
  // Tier 1 — Flak / Screen
  gunboat,
  interceptor,
  flakFrigate,
  // Tier 2 — Line / Middle
  destroyer,
  heavyCruiser,
  ewCruiser,
  strikeCarrier,
  repairTender,
  // Tier 3 — Capitals
  battlecruiser,
  dreadnought,
}

/// Determines how quickly a ship responds to thrust and turn commands.
enum MassClass {
  light,   // gunboat, interceptor, flak frigate, destroyer
  medium,  // strike carrier, ew cruiser, repair tender
  heavy,   // heavy cruiser, battlecruiser
  capital, // flagship, dreadnought
}

/// Tactical tags used by the AI and combat resolution system.
enum RoleTag {
  // Existing
  directFire,
  missile,
  pointDefense,
  screening, // legacy — no longer assigned to new hulls
  flanking,
  // M7 additions
  torpedo,
  intercept,
  flak,
  jamming,
  repair,
  heavyBroadside,
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
  double torpedoReloadUntil = 0.0; // battle time when torpedo salvo is ready

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
