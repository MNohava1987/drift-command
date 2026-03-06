import 'dart:math' as math;
import 'package:flame/components.dart';
import '../models/ship_data.dart';
import '../models/battle_state.dart';
import '../../data/balance/combat_balance.dart';

/// Handles combat resolution: auto-fire, damage application, kill detection.
///
/// Resolution order each tick:
/// 1. Standard weapon fire (directFire, missile, torpedo)
/// 2. Flak area burst (separate pass — affects friends + foes)
/// 3. Repair aura (heal pass)
/// 4. Death detection
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

    // ── Standard weapon fire ───────────────────────────────────────────────
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

    // ── Flak area burst (friend + foe within radius) ───────────────────────
    for (final attacker in alive) {
      final data = shipDataRegistry[attacker.dataId];
      if (data == null) continue;
      if (!data.roleTags.contains(RoleTag.flak)) continue;

      final aliveFlagged = state.ships.values.where((s) => s.isAlive).toList();
      for (final ship in aliveFlagged) {
        if (ship.instanceId == attacker.instanceId) continue;
        final dist = attacker.position.distanceTo(ship.position);
        if (dist <= kFlakAreaRadius) {
          final dmg = (kWeaponDps[RoleTag.directFire] ?? 8.0) * dt;
          ship.durability -= dmg;
          ship.durability = ship.durability.clamp(0, double.infinity);
          ship.lastHitAt = state.battleTime;
        }
      }
    }

    // ── Repair aura ────────────────────────────────────────────────────────
    for (final tender in alive) {
      final data = shipDataRegistry[tender.dataId];
      if (data == null) continue;
      if (!data.roleTags.contains(RoleTag.repair)) continue;

      for (final ally in state.ships.values) {
        if (!ally.isAlive) continue;
        if (ally.factionId != tender.factionId) continue;
        final dist = tender.position.distanceTo(ally.position);
        if (dist <= kRepairRange) {
          final maxDur = shipDataRegistry[ally.dataId]?.maxDurability ?? ally.durability;
          ally.durability = (ally.durability + kRepairHps * dt).clamp(0, maxDur);
        }
      }
    }

    // ── Death detection ────────────────────────────────────────────────────
    for (final ship in state.ships.values) {
      if (ship.durability <= 0 && ship.isAlive) {
        ship.isAlive = false;
      }
    }
  }

  bool _hasOffensiveWeapons(ShipData data) {
    return data.roleTags.any((t) =>
        t == RoleTag.directFire || t == RoleTag.missile || t == RoleTag.torpedo);
  }

  ShipState? _selectTarget(
      ShipState attacker, BattleState state, ShipData data) {
    final enemies = state.ships.values
        .where((s) => s.isAlive && s.factionId != attacker.factionId)
        .toList();

    double effectiveRange = attacker.shipMode == ShipMode.attack
        ? data.weaponRange * kAttackModeRangeBonus
        : data.weaponRange;

    // Jamming: check if attacker is inside any enemy EW Cruiser field
    final jammed = state.ships.values.any((s) =>
        s.isAlive &&
        s.factionId != attacker.factionId &&
        (shipDataRegistry[s.dataId]?.roleTags.contains(RoleTag.jamming) ?? false) &&
        s.position.distanceTo(attacker.position) <= kJammingRange);
    if (jammed) effectiveRange *= (1.0 - kJammingRangePenalty);

    // Intercept: prefer missile carriers (strike carriers)
    if (data.roleTags.contains(RoleTag.intercept)) {
      final missileCarrier = enemies.where((e) {
        final dist = attacker.position.distanceTo(e.position);
        final eDat = shipDataRegistry[e.dataId];
        return dist <= effectiveRange &&
            (eDat?.roleTags.contains(RoleTag.missile) ?? false);
      }).fold<ShipState?>(null, (best, e) {
        if (best == null) return e;
        return attacker.position.distanceTo(e.position) <
                attacker.position.distanceTo(best.position)
            ? e
            : best;
      });
      if (missileCarrier != null) return missileCarrier;
    }

    // Default: nearest enemy in range
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

    // ── Direct fire ───────────────────────────────────────────────────────
    if (data.roleTags.contains(RoleTag.directFire)) {
      damage += (kWeaponDps[RoleTag.directFire] ?? 0) * dt;
    }

    // ── Missile ───────────────────────────────────────────────────────────
    if (data.roleTags.contains(RoleTag.missile)) {
      isMissile = true;
      double missileDmg = (kWeaponDps[RoleTag.missile] ?? 0) * dt;
      if (_hasNearbyPointDefense(target, state)) {
        missileDmg *= (1.0 - kPointDefenseInterceptRate);
      }
      damage += missileDmg;
    }

    // ── Torpedo salvo (ignores point defense) ─────────────────────────────
    if (data.roleTags.contains(RoleTag.torpedo)) {
      if (attacker.torpedoReloadUntil <= state.battleTime) {
        // Burst: 3× concentrated damage (applied instantly this tick)
        final burst = kTorpedoSalvoMultiplier *
            (kWeaponDps[RoleTag.directFire] ?? 8.0) *
            dt;
        damage += burst;
        attacker.torpedoReloadUntil = state.battleTime + kTorpedoReloadTime;
      }
      // During reload: no torpedo damage (skip)
    }

    // ── Mode modifiers ────────────────────────────────────────────────────
    if (attacker.shipMode == ShipMode.attack) {
      damage *= kAttackModeDamageBonus;
    }
    if (target.shipMode == ShipMode.defensive) {
      damage *= kDefensiveModeReduction;
    }

    // ── Flanking bonus (rear arc) ─────────────────────────────────────────
    if (data.roleTags.contains(RoleTag.flanking) && damage > 0) {
      final toTarget = attacker.position - target.position;
      final targetFwd =
          Vector2(math.cos(target.heading), math.sin(target.heading));
      final dot = toTarget.normalized().dot(targetFwd);
      // dot < 0 means attacker is behind target (rear arc)
      if (dot < 0) damage *= kFlankingDamageBonus;
    }

    // ── Heavy broadside bonus (perpendicular fire) ────────────────────────
    if (data.roleTags.contains(RoleTag.heavyBroadside) && damage > 0) {
      final toTargetDir = (target.position - attacker.position).normalized();
      final attackerFwd =
          Vector2(math.cos(attacker.heading), math.sin(attacker.heading));
      // perp ≈ 0 when perpendicular (broadside), ≈ 1 when head-on
      final perp = toTargetDir.dot(attackerFwd).abs();
      final broadsideFactor = 1.0 + kHeavyBroadsideBonus * (1.0 - perp);
      damage *= broadsideFactor;
    }

    if (damage > 0) {
      target.lastHitAt = state.battleTime;

      if (onFire != null && !_fireCooldowns.containsKey(attacker.instanceId)) {
        onFire!(attacker.position.clone(), target.position.clone(), isMissile);
        _fireCooldowns[attacker.instanceId] = 0.4;
      }
    }

    target.durability -= damage;
    target.durability = target.durability.clamp(0, double.infinity);
  }

  bool _hasNearbyPointDefense(ShipState target, BattleState state) {
    return state.ships.values.any((s) =>
        s.isAlive &&
        s.factionId == target.factionId &&
        s.instanceId != target.instanceId &&
        s.shipMode == ShipMode.defensive &&
        (shipDataRegistry[s.dataId]?.roleTags.contains(RoleTag.pointDefense) ?? false) &&
        s.position.distanceTo(target.position) <= kPointDefenseRange);
  }
}
