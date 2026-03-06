import 'package:flame/components.dart';
import '../models/ship_data.dart';
import '../models/battle_state.dart';

/// Damage per second for each weapon category (MVP placeholder values).
const Map<RoleTag, double> kWeaponDps = {
  RoleTag.directFire: 8.0,
  RoleTag.missile: 15.0,
  RoleTag.pointDefense: 5.0,
};

const double kPointDefenseInterceptRate = 0.4; // 40% missile reduction

/// Handles combat resolution: auto-fire, damage application, kill detection.
///
/// MVP combat is intentionally simple:
/// - Ships auto-fire when a valid target is in weapon range and facing arc
/// - No player-driven targeting — doctrine and orders drive target selection
/// - No subsystem damage
class CombatSystem {
  final Map<String, ShipData> shipDataRegistry;

  /// Called when a ship fires — spawn visual projectile in BattleGame.
  void Function(Vector2 from, Vector2 to, bool isMissile)? onFire;

  /// Per-attacker cooldown so we don't spawn a projectile every tick.
  final Map<String, double> _fireCooldowns = {};

  CombatSystem({required this.shipDataRegistry});

  void update(BattleState state, double dt) {
    final alive = state.ships.values.where((s) => s.isAlive).toList();

    // Decrement per-attacker fire visual cooldowns
    for (final key in _fireCooldowns.keys.toList()) {
      final v = _fireCooldowns[key]! - dt;
      if (v <= 0) {
        _fireCooldowns.remove(key);
      } else {
        _fireCooldowns[key] = v;
      }
    }

    for (final attacker in alive) {
      final data = shipDataRegistry[attacker.dataId];
      if (data == null) continue;
      if (!_hasOffensiveWeapons(data)) continue;

      final target = _selectTarget(attacker, state, data);
      if (target == null) continue;

      _applyDamage(
        attacker: attacker,
        target: target,
        targetData: shipDataRegistry[target.dataId],
        data: data,
        state: state,
        dt: dt,
      );
    }

    // Check for deaths
    for (final ship in state.ships.values) {
      if (ship.durability <= 0 && ship.isAlive) {
        ship.isAlive = false;
      }
    }
  }

  bool _hasOffensiveWeapons(ShipData data) {
    return data.roleTags.any((t) => t == RoleTag.directFire || t == RoleTag.missile);
  }

  ShipState? _selectTarget(
      ShipState attacker, BattleState state, ShipData data) {
    final enemies = state.ships.values
        .where((s) => s.isAlive && s.factionId != attacker.factionId)
        .toList();

    final effectiveRange = attacker.shipMode == ShipMode.attack
        ? data.weaponRange * 1.15
        : data.weaponRange;

    ShipState? closest;
    double minDist = double.infinity;

    for (final enemy in enemies) {
      final dist = attacker.position.distanceTo(enemy.position);
      if (dist <= effectiveRange && dist < minDist) {
        minDist = dist;
        closest = enemy;
      }
    }

    return closest;
  }

  void _applyDamage({
    required ShipState attacker,
    required ShipState target,
    required ShipData? targetData,
    required ShipData data,
    required BattleState state,
    required double dt,
  }) {
    double damage = 0;
    bool isMissile = false;

    if (data.roleTags.contains(RoleTag.directFire)) {
      damage += (kWeaponDps[RoleTag.directFire] ?? 0) * dt;
    }

    if (data.roleTags.contains(RoleTag.missile)) {
      isMissile = true;
      double missileDmg = (kWeaponDps[RoleTag.missile] ?? 0) * dt;

      // Check if target has point defense coverage from allied escorts in defensive mode
      final hasPointDefense = _hasNearbyPointDefense(target, state);
      if (hasPointDefense) {
        missileDmg *= (1.0 - kPointDefenseInterceptRate);
      }

      damage += missileDmg;
    }

    // Attack mode attacker deals more damage
    if (attacker.shipMode == ShipMode.attack) {
      damage *= 1.25;
    }

    // Defensive mode target absorbs less damage
    if (target.shipMode == ShipMode.defensive) {
      damage *= 0.80;
    }

    if (damage > 0) {
      target.lastHitAt = state.battleTime;

      // Spawn visual projectile (throttled per attacker)
      if (onFire != null && !_fireCooldowns.containsKey(attacker.instanceId)) {
        onFire!(attacker.position.clone(), target.position.clone(), isMissile);
        _fireCooldowns[attacker.instanceId] = 0.4;
      }
    }

    target.durability -= damage;
    target.durability = target.durability.clamp(0, double.infinity);
  }

  bool _hasNearbyPointDefense(ShipState target, BattleState state) {
    const double pdRange = 160.0; // doubled for 2× world scale
    return state.ships.values.any((s) =>
        s.isAlive &&
        s.factionId == target.factionId &&
        s.instanceId != target.instanceId &&
        s.shipMode == ShipMode.defensive &&
        (shipDataRegistry[s.dataId]?.roleTags.contains(RoleTag.pointDefense) ?? false) &&
        s.position.distanceTo(target.position) <= pdRange);
  }
}
