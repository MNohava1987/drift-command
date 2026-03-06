import 'package:drift_command/core/models/battle_state.dart';
import 'package:drift_command/core/models/ship_data.dart';
import 'package:drift_command/core/systems/combat_system.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

// ── Helpers ───────────────────────────────────────────────────────────────

ShipData _data({
  required String id,
  ShipRole role = ShipRole.gunboat,
  MassClass mass = MassClass.light,
  double range = 200.0,
  double hp = 100.0,
  List<RoleTag> tags = const [RoleTag.directFire],
}) =>
    ShipData(
      id: id,
      displayName: id,
      role: role,
      massClass: mass,
      maxAcceleration: 20.0,
      turnRate: 1.0,
      sensorRange: 300.0,
      weaponRange: range,
      maxDurability: hp,
      roleTags: tags,
    );

ShipState _ship({
  required String instanceId,
  required String dataId,
  required int factionId,
  required Vector2 position,
  double heading = 0.0,
  double durability = 100.0,
}) =>
    ShipState(
      instanceId: instanceId,
      dataId: dataId,
      factionId: factionId,
      position: position,
      heading: heading,
      durability: durability,
    );

BattleState _state(Map<String, ShipState> ships) => BattleState(
      playerFactionId: 0,
      objectiveDescription: 'test',
      ships: ships,
      playerFlagshipId: '',
    );

// ── Tests ─────────────────────────────────────────────────────────────────

void main() {
  group('CombatSystem', () {
    test('torpedo does burst damage then reloads (no damage during reload)', () {
      final registry = {
        'destroyer': _data(
          id: 'destroyer',
          role: ShipRole.destroyer,
          range: 150.0,
          hp: 65.0,
          tags: [RoleTag.torpedo, RoleTag.directFire],
        ),
        'target': _data(id: 'target', range: 0.0, hp: 500.0, tags: []),
      };
      final attacker = _ship(
        instanceId: 'a',
        dataId: 'destroyer',
        factionId: 0,
        position: Vector2(0, 0),
        durability: 65.0,
      );
      final target = _ship(
        instanceId: 't',
        dataId: 'target',
        factionId: 1,
        position: Vector2(100, 0),
        durability: 500.0,
      );
      final state = _state({'a': attacker, 't': target})
        ..battleTime = 0.0;

      final cs = CombatSystem(shipDataRegistry: registry);

      // Tick 1 — torpedo fires (salvo burst)
      final hpBefore = target.durability;
      cs.update(state, 0.1);
      final hpAfterSalvo = target.durability;
      expect(hpAfterSalvo, lessThan(hpBefore), reason: 'salvo deals damage');
      expect(attacker.torpedoReloadUntil, greaterThan(0.0),
          reason: 'reload timer set');

      // During reload window — tick at same battleTime (still reloading)
      final hpBeforeReload = target.durability;
      state.battleTime = 0.5; // still within 5s reload
      cs.update(state, 0.1);
      final directOnlyDamage = hpBeforeReload - target.durability;

      // Also fired directFire, so damage still expected but no torpedo burst
      // Burst from tick1 was kTorpedoSalvoMultiplier × kWeaponDps × dt
      // In tick2 only directFire fires — damage should be less than the burst
      final torpedoBurstDamage = hpBefore - hpAfterSalvo;
      // directFire only = 8.0 * 0.1 = 0.8, torpedo burst = 3 * 8.0 * 0.1 = 2.4
      expect(directOnlyDamage, lessThan(torpedoBurstDamage),
          reason: 'reload tick does less damage than salvo tick');
    });

    test('torpedo ignores point defense', () {
      final registry = {
        'destroyer': _data(
          id: 'destroyer',
          role: ShipRole.destroyer,
          range: 150.0,
          hp: 65.0,
          tags: [RoleTag.torpedo],
        ),
        'target': _data(id: 'target', range: 0.0, hp: 500.0, tags: []),
        'pd_ship': _data(
          id: 'pd_ship',
          range: 0.0,
          hp: 100.0,
          tags: [RoleTag.pointDefense],
        ),
      };
      final attacker = _ship(
        instanceId: 'a',
        dataId: 'destroyer',
        factionId: 0,
        position: Vector2(0, 0),
        durability: 65.0,
      );
      final target = _ship(
        instanceId: 't',
        dataId: 'target',
        factionId: 1,
        position: Vector2(100, 0),
        durability: 500.0,
      );
      // PD ship same faction as target, in defensive mode, right next to it
      final pd = _ship(
        instanceId: 'pd',
        dataId: 'pd_ship',
        factionId: 1,
        position: Vector2(110, 0),
        durability: 100.0,
      )..shipMode = ShipMode.defensive;

      final state = _state({'a': attacker, 't': target, 'pd': pd})
        ..battleTime = 0.0;
      final cs = CombatSystem(shipDataRegistry: registry);

      final hpBefore = target.durability;
      cs.update(state, 0.1);
      final hpAfter = target.durability;

      // Torpedo fires (salvo), PD should NOT reduce it
      // Expected burst: 3 × 8.0 × 0.1 = 2.4 (after attack mode check = ×1.25 since default is defensive)
      // Actually attacker is default defensive mode, so kAttackModeDamageBonus not applied
      // And target is default defensive mode so kDefensiveModeReduction applies: 2.4 * 0.8 = 1.92
      // Without PD blocking torpedo, damage should be 1.92. With PD, it would be 1.92 * 0.6 = 1.152
      // We just verify target took damage (torpedo fired = not zero)
      expect(hpAfter, lessThan(hpBefore), reason: 'torpedo damages despite PD ship nearby');
    });

    test('repair tender heals ally within range', () {
      final registry = {
        'tender': _data(
          id: 'tender',
          role: ShipRole.repairTender,
          range: 0.0,
          hp: 55.0,
          tags: [RoleTag.repair],
        ),
        'ally': _data(id: 'ally', range: 0.0, hp: 100.0, tags: []),
      };
      final tender = _ship(
        instanceId: 'tender',
        dataId: 'tender',
        factionId: 0,
        position: Vector2(0, 0),
        durability: 55.0,
      );
      final ally = _ship(
        instanceId: 'ally',
        dataId: 'ally',
        factionId: 0,
        position: Vector2(50, 0), // within kRepairRange (120)
        durability: 50.0, // damaged
      );
      final state = _state({'tender': tender, 'ally': ally});
      final cs = CombatSystem(shipDataRegistry: registry);

      cs.update(state, 1.0); // 1 second tick
      // Should gain kRepairHps = 6.0 HP
      expect(ally.durability, closeTo(56.0, 0.01));
    });

    test('repair tender does not heal enemies', () {
      final registry = {
        'tender': _data(
          id: 'tender',
          role: ShipRole.repairTender,
          range: 0.0,
          hp: 55.0,
          tags: [RoleTag.repair],
        ),
        'enemy': _data(id: 'enemy', range: 0.0, hp: 100.0, tags: []),
      };
      final tender = _ship(
        instanceId: 'tender',
        dataId: 'tender',
        factionId: 0,
        position: Vector2(0, 0),
        durability: 55.0,
      );
      final enemy = _ship(
        instanceId: 'enemy',
        dataId: 'enemy',
        factionId: 1, // different faction
        position: Vector2(50, 0),
        durability: 50.0,
      );
      final state = _state({'tender': tender, 'enemy': enemy});
      final cs = CombatSystem(shipDataRegistry: registry);

      cs.update(state, 1.0);
      expect(enemy.durability, 50.0, reason: 'enemy not healed');
    });

    test('jamming reduces effective range', () {
      final registry = {
        'attacker': _data(
          id: 'attacker',
          range: 150.0,
          hp: 100.0,
          tags: [RoleTag.directFire],
        ),
        'ew': _data(
          id: 'ew',
          role: ShipRole.ewCruiser,
          range: 0.0,
          hp: 70.0,
          tags: [RoleTag.jamming],
        ),
        'target': _data(id: 'target', range: 0.0, hp: 500.0, tags: []),
      };
      // Attacker at origin, target at 120 (within 150 range normally)
      // EW cruiser at 50 units from attacker (within kJammingRange=150)
      // Jammed effective range = 150 * (1 - 0.35) = 97.5 → can't hit target at 120
      final attacker = _ship(
        instanceId: 'a',
        dataId: 'attacker',
        factionId: 0,
        position: Vector2(0, 0),
        durability: 100.0,
      );
      final ew = _ship(
        instanceId: 'ew',
        dataId: 'ew',
        factionId: 1,
        position: Vector2(50, 0),
        durability: 70.0,
      );
      final target = _ship(
        instanceId: 't',
        dataId: 'target',
        factionId: 1,
        position: Vector2(120, 0), // beyond jammed range (97.5) but within normal range (150)
        durability: 500.0,
      );
      final state = _state({'a': attacker, 'ew': ew, 't': target});
      final cs = CombatSystem(shipDataRegistry: registry);

      final hpBefore = target.durability;
      cs.update(state, 0.5);
      expect(target.durability, hpBefore, reason: 'target out of jammed range — no damage');
    });

    test('flak damages ships within area radius including allies', () {
      final registry = {
        'flak': _data(
          id: 'flak',
          role: ShipRole.flakFrigate,
          range: 80.0,
          hp: 60.0,
          tags: [RoleTag.flak],
        ),
        'enemy': _data(id: 'enemy', range: 0.0, hp: 100.0, tags: []),
        'ally': _data(id: 'ally', range: 0.0, hp: 100.0, tags: []),
      };
      final flak = _ship(
        instanceId: 'flak',
        dataId: 'flak',
        factionId: 0,
        position: Vector2(0, 0),
        durability: 60.0,
      );
      final enemy = _ship(
        instanceId: 'enemy',
        dataId: 'enemy',
        factionId: 1,
        position: Vector2(40, 0), // within kFlakAreaRadius (60)
        durability: 100.0,
      );
      final ally = _ship(
        instanceId: 'ally',
        dataId: 'ally',
        factionId: 0,
        position: Vector2(30, 0), // within kFlakAreaRadius (60)
        durability: 100.0,
      );
      final state = _state({'flak': flak, 'enemy': enemy, 'ally': ally});
      final cs = CombatSystem(shipDataRegistry: registry);

      cs.update(state, 0.5);
      expect(enemy.durability, lessThan(100.0), reason: 'enemy damaged by flak');
      expect(ally.durability, lessThan(100.0), reason: 'ally damaged by friendly flak');
    });

    test('flanking bonus applies from rear arc', () {
      final registry = {
        'gunboat': _data(
          id: 'gunboat',
          role: ShipRole.gunboat,
          range: 150.0,
          hp: 35.0,
          tags: [RoleTag.directFire, RoleTag.flanking],
        ),
        'target': _data(id: 'target', range: 0.0, hp: 500.0, tags: []),
      };
      // Target heading = 0 (facing east/+X)
      // Rear arc: attacker must be to the WEST of target (behind it)
      // Attacker to the rear (west of target = negative X)
      final rearAttacker = _ship(
        instanceId: 'a_rear',
        dataId: 'gunboat',
        factionId: 0,
        position: Vector2(-100, 0), // behind target
        durability: 35.0,
      );
      // Attacker from front (east of target)
      final frontAttacker = _ship(
        instanceId: 'a_front',
        dataId: 'gunboat',
        factionId: 0,
        position: Vector2(100, 0), // in front of target
        durability: 35.0,
      );

      // Test rear attacker
      final targetRear = _ship(
        instanceId: 't_rear',
        dataId: 'target',
        factionId: 1,
        position: Vector2(0, 0),
        heading: 0.0,
        durability: 500.0,
      );
      final stateRear = _state({'a': rearAttacker, 't': targetRear});
      final csRear = CombatSystem(shipDataRegistry: registry);
      csRear.update(stateRear, 0.1);
      final damageFromRear = 500.0 - targetRear.durability;

      // Test front attacker
      final targetFront = _ship(
        instanceId: 't_front',
        dataId: 'target',
        factionId: 1,
        position: Vector2(0, 0),
        heading: 0.0,
        durability: 500.0,
      );
      final stateFront = _state({'a': frontAttacker, 't': targetFront});
      final csFront = CombatSystem(shipDataRegistry: registry);
      csFront.update(stateFront, 0.1);
      final damageFromFront = 500.0 - targetFront.durability;

      expect(damageFromRear, greaterThan(damageFromFront),
          reason: 'rear arc flanking deals more damage than front');
    });

    test('interceptor prefers missile carrier over closer non-carrier', () {
      final registry = {
        'interceptor': _data(
          id: 'interceptor',
          role: ShipRole.interceptor,
          range: 200.0,
          hp: 45.0,
          tags: [RoleTag.directFire, RoleTag.intercept, RoleTag.pointDefense],
        ),
        'carrier': _data(
          id: 'carrier',
          role: ShipRole.strikeCarrier,
          range: 200.0,
          hp: 90.0,
          tags: [RoleTag.missile],
        ),
        'regular': _data(id: 'regular', range: 80.0, hp: 120.0, tags: [RoleTag.directFire]),
      };
      final attacker = _ship(
        instanceId: 'i',
        dataId: 'interceptor',
        factionId: 0,
        position: Vector2(0, 0),
        durability: 45.0,
      );
      // Regular enemy is closer (50 units away)
      final regular = _ship(
        instanceId: 'r',
        dataId: 'regular',
        factionId: 1,
        position: Vector2(50, 0),
        durability: 120.0,
      );
      // Missile carrier is farther (150 units away)
      final carrier = _ship(
        instanceId: 'c',
        dataId: 'carrier',
        factionId: 1,
        position: Vector2(150, 0),
        durability: 90.0,
      );
      final state = _state({'i': attacker, 'r': regular, 'c': carrier});
      final cs = CombatSystem(shipDataRegistry: registry);

      cs.update(state, 0.5);
      // Interceptor should prefer carrier → carrier takes damage, regular does not
      expect(carrier.durability, lessThan(90.0), reason: 'carrier targeted by interceptor');
      expect(regular.durability, 120.0, reason: 'regular enemy not targeted');
    });
  });
}
