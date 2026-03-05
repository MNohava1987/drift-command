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

  CombatSystem({required this.shipDataRegistry});

  void update(BattleState state, double dt) {
    final alive = state.ships.values.where((s) => s.isAlive).toList();

    for (final attacker in alive) {
      final data = shipDataRegistry[attacker.dataId];
      if (data == null) continue;
      if (!_hasOffensiveWeapons(data)) continue;

      final target = _selectTarget(attacker, state, data);
      if (target == null) continue;

      _applyDamage(attacker: attacker, target: target, targetData: shipDataRegistry[target.dataId], data: data, state: state, dt: dt);
    }

    // Check for deaths
    for (final ship in state.ships.values) {
      if (ship.durability <= 0 && ship.isAlive) {
        ship.isAlive = false;
        ship.pendingOrders.clear();
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

    ShipState? closest;
    double minDist = double.infinity;

    for (final enemy in enemies) {
      final dist = attacker.position.distanceTo(enemy.position);
      if (dist <= data.weaponRange && dist < minDist) {
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

    if (data.roleTags.contains(RoleTag.directFire)) {
      damage += (kWeaponDps[RoleTag.directFire] ?? 0) * dt;
    }

    if (data.roleTags.contains(RoleTag.missile)) {
      double missileDmg = (kWeaponDps[RoleTag.missile] ?? 0) * dt;

      // Check if target has point defense coverage from allied escorts
      final hasPointDefense = _hasNearbyPointDefense(target, state);
      if (hasPointDefense) {
        missileDmg *= (1.0 - kPointDefenseInterceptRate);
      }

      damage += missileDmg;
    }

    target.durability -= damage;
    target.durability = target.durability.clamp(0, double.infinity);
  }

  bool _hasNearbyPointDefense(ShipState target, BattleState state) {
    const double pdRange = 80.0;
    return state.ships.values.any((s) =>
        s.isAlive &&
        s.factionId == target.factionId &&
        s.instanceId != target.instanceId &&
        (shipDataRegistry[s.dataId]?.roleTags.contains(RoleTag.pointDefense) ?? false) &&
        s.position.distanceTo(target.position) <= pdRange);
  }
}
