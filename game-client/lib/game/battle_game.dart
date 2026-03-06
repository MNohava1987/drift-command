import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' show Color;

import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart';
import 'package:flame_audio/flame_audio.dart';

import '../core/models/battle_state.dart';
import '../core/models/ship_data.dart';
import '../core/systems/kinematic_system.dart';
import '../core/systems/command_system.dart';
import '../core/systems/tempo_system.dart';
import '../core/systems/combat_system.dart';
import '../core/ai/doctrine_ai.dart';
import '../core/services/scenario_loader.dart';
import '../data/ships/ship_definitions.dart';
import 'components/battlefield_renderer.dart';

/// Root Flame game. Owns the simulation loop and exposes ValueNotifiers
/// for Flutter HUD widgets.
class BattleGame extends FlameGame with TapCallbacks, ScrollDetector {
  final String scenarioAssetPath;
  final bool carryDamage;
  final Map<String, double>? startingDurabilityFractions;

  BattleGame({
    this.scenarioAssetPath = 'assets/scenarios/scenario_001.json',
    this.carryDamage = false,
    this.startingDurabilityFractions,
  });

  // ── Systems ──────────────────────────────────────────────────────────────
  final _tempoSystem = TempoSystem();
  final _commandSystem = CommandSystem();
  late final KinematicSystem _kinematics;
  late final CombatSystem _combat;
  late final DoctrineAI _ai;

  // ── State ────────────────────────────────────────────────────────────────
  late BattleState _state;
  bool _isInitialized = false;
  ShipState? _selectedShip;
  late BattlefieldRenderer _renderer;

  /// Approach speed for the next issued order: 0.25 / 0.5 / 1.0
  double selectedSpeed = 0.5;

  /// Simulation time multiplier. 0.0 = planning freeze, 1.0 = real time.
  double _timeScale = 0.0;

  /// When true, tap orders apply to the whole fleet (maintaining formation offsets).
  bool fleetMode = false;
  final fleetModeNotifier = ValueNotifier<bool>(false);

  /// Visual-only transit pulses. Each entry is [fromPos, toPos, progress 0→1, speed].
  final List<TransitPulse> transitPulses = [];

  /// Particle explosions (visual only).
  final List<BattleParticle> particles = [];

  /// Visual projectiles — cosmetic only, damage is still instant.
  final List<Projectile> projectiles = [];

  final _rng = math.Random();
  double _weaponSoundCooldown = 0.0;
  bool _audioReady = false;

  // ── Formation presets: offsets by role for each named formation. ─────────
  // Offsets are relative to flagship position (world units).
  // Two entries per role = two ships of that type get different slots.
  static final Map<String, Map<ShipRole, List<Vector2>>> kFormations = {
    'WEDGE': {
      ShipRole.flagship: [Vector2(0, 0)],
      ShipRole.commandRelay: [Vector2(-200, 0)],
      ShipRole.heavyLine: [Vector2(-80, -130), Vector2(-80, 130)],
      ShipRole.lightEscort: [Vector2(-50, -70), Vector2(-50, 70)],
      ShipRole.fastRaider: [Vector2(80, -160), Vector2(80, 160)],
      ShipRole.strikeCarrier: [Vector2(-150, 0)],
    },
    'SCREEN': {
      ShipRole.flagship: [Vector2(0, 0)],
      ShipRole.commandRelay: [Vector2(-160, 0)],
      ShipRole.heavyLine: [Vector2(120, -60), Vector2(120, 60)],
      ShipRole.lightEscort: [Vector2(90, -160), Vector2(90, 160)],
      ShipRole.fastRaider: [Vector2(160, -220), Vector2(160, 220)],
      ShipRole.strikeCarrier: [Vector2(-120, 0)],
    },
    'DIAMOND': {
      ShipRole.flagship: [Vector2(0, 0)],
      ShipRole.commandRelay: [Vector2(-160, 0)],
      ShipRole.heavyLine: [Vector2(120, 0), Vector2(0, 120)],
      ShipRole.lightEscort: [Vector2(0, -110), Vector2(-90, 110)],
      ShipRole.fastRaider: [Vector2(160, -120), Vector2(160, 120)],
      ShipRole.strikeCarrier: [Vector2(-110, 0)],
    },
  };

  // ── HUD notifiers (listened to by Flutter widgets) ───────────────────────
  final tempoBandNotifier = ValueNotifier<TempoBand>(TempoBand.distant);
  final selectedShipNotifier = ValueNotifier<ShipState?>(null);
  final battlePhaseNotifier = ValueNotifier<BattlePhase>(BattlePhase.setup);
  final battleTimeTextNotifier = ValueNotifier<String>('0:00');
  final commandPulseReadyNotifier = ValueNotifier<bool>(false);
  final isPausedNotifier = ValueNotifier<bool>(false);
  final timeScaleNotifier = ValueNotifier<double>(0.0);

  // ── Public accessors ─────────────────────────────────────────────────────
  BattleState get battleState => _state;
  BattleState? get battleStateOrNull => _isInitialized ? _state : null;
  ShipState? get selectedShipState => _selectedShip;

  @override
  Future<void> onLoad() async {
    _kinematics = KinematicSystem(shipDataRegistry: kShipDefinitions);
    _combat = CombatSystem(shipDataRegistry: kShipDefinitions);
    _combat.onFire = _spawnProjectile;
    _ai = DoctrineAI(commandSystem: _commandSystem, registry: kShipDefinitions);

    final jsonStr = await rootBundle.loadString(scenarioAssetPath);
    final jsonMap = jsonDecode(jsonStr) as Map<String, dynamic>;
    _state = ScenarioLoader.fromJson(
      jsonMap,
      kShipDefinitions,
      carryDamage: carryDamage,
      startingDurabilityFractions: startingDurabilityFractions,
    );

    try {
      await FlameAudio.audioCache.loadAll([
        'order_click.ogg',
        'weapon_fire.ogg',
        'explosion.ogg',
        'engine_hum.ogg',
      ]);
      _audioReady = true;
    } catch (_) {}

    _renderer = BattlefieldRenderer(this);
    await add(_renderer);

    _isInitialized = true;
    _state.phase = BattlePhase.active;
    battlePhaseNotifier.value = BattlePhase.active;
    // Start frozen at 0× so the player can survey the battlefield before engaging
    timeScaleNotifier.value = 0.0;
    overlays.add('hud');
  }

  /// Set simulation time multiplier. 0.0 = frozen, 0.5 = half speed, 4.0 = 4× speed.
  void setTimeScale(double scale) {
    _timeScale = scale;
    timeScaleNotifier.value = scale;
  }

  /// Unfreeze from planning phase — called by the ENGAGE button.
  void engageBattle() {
    if (_timeScale == 0.0) setTimeScale(1.0);
  }

  /// Toggle fleet-command mode on/off.
  void toggleFleetMode() {
    fleetMode = !fleetMode;
    fleetModeNotifier.value = fleetMode;
  }

  /// Apply a named formation preset — issues moveTo orders to all player ships
  /// offset from flagship's current position.
  void applyFormation(String name) {
    if (!_isInitialized) return;
    if (!_tempoSystem.isCommandPulseReady(_state)) return;
    final offsets = kFormations[name];
    if (offsets == null) return;
    final flagship = _getPlayerFlagship();
    if (flagship == null || !flagship.isAlive) return;

    const int maxPending = 6;
    final roleCounters = <ShipRole, int>{};
    for (final ship in _state.ships.values) {
      if (!ship.isAlive || ship.factionId != _state.playerFactionId) continue;
      if (ship.pendingOrders.length >= maxPending) continue;
      final role = _roleForShip(ship);
      final idx = roleCounters[role] ?? 0;
      roleCounters[role] = idx + 1;
      final roleOffsets = offsets[role];
      final offset = (roleOffsets != null && idx < roleOffsets.length)
          ? roleOffsets[idx]
          : Vector2.zero();
      _commandSystem.issueOrder(
        state: _state,
        targetShipId: ship.instanceId,
        orderType: OrderType.moveTo,
        targetPosition: flagship.position + offset,
        registry: kShipDefinitions,
        targetSpeedFraction: selectedSpeed,
      );
    }
    _tempoSystem.advanceCommandPulse(_state);
    commandPulseReadyNotifier.value = false;
    _spawnOrderPulse(flagship);
    playSound('order_click.ogg');
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!_isInitialized) return;
    if (_state.phase != BattlePhase.active) return;

    if (isPausedNotifier.value) return;
    final scaledDt = dt * _timeScale;

    if (scaledDt > 0) {
      _tempoSystem.update(_state, scaledDt);
      _ai.update(_state, scaledDt);

      final aliveShips = _state.ships.values.where((s) => s.isAlive).toList();
      _kinematics.update(
        aliveShips,
        scaledDt,
        battleTime: _state.battleTime,
        allShips: _state.ships,
      );

      // Snapshot alive status before combat resolves this tick
      final wasAlive = {for (final e in _state.ships.entries) e.key: e.value.isAlive};

      _combat.update(_state, scaledDt);

      // Detect new deaths and spawn explosions; weapon fire sound (throttled)
      bool combatHappened = false;
      for (final ship in _state.ships.values) {
        if (wasAlive[ship.instanceId] == true && !ship.isAlive) {
          _spawnExplosion(ship);
        }
      }
      // Throttled weapon fire sound: fire if any ship is in combat this tick
      if (_weaponSoundCooldown <= 0) {
        combatHappened = _state.ships.values.any((attacker) {
          if (!attacker.isAlive) return false;
          return _state.ships.values.any((target) =>
              target.isAlive &&
              target.factionId != attacker.factionId &&
              attacker.position.distanceTo(target.position) <=
                  (kShipDefinitions[attacker.dataId]?.weaponRange ?? 0) * 1.2);
        });
        if (combatHappened) {
          playSound('weapon_fire.ogg');
          _weaponSoundCooldown = 1.0;
        }
      }

      _checkWinLoss();
      _advanceTransitPulses(scaledDt);
      _advanceParticles(scaledDt);
      _advanceProjectiles(scaledDt);

      if (_weaponSoundCooldown > 0) _weaponSoundCooldown -= scaledDt;
    }

    // Refresh HUD notifiers (even at 0×)
    tempoBandNotifier.value = _state.tempoBand;
    commandPulseReadyNotifier.value = _tempoSystem.isCommandPulseReady(_state);
    final t = _state.battleTime.toInt();
    battleTimeTextNotifier.value =
        '${t ~/ 60}:${(t % 60).toString().padLeft(2, '0')}';
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (!_isInitialized) return;
    if (_state.phase != BattlePhase.active) return;

    final worldPos = _renderer.canvasToWorld(event.localPosition);
    const double selectionRadius = 40.0;

    // Check if tapping a player ship → select it
    ShipState? tappedPlayer;
    double nearestPlayer = double.infinity;
    for (final ship in _state.ships.values) {
      if (!ship.isAlive || ship.factionId != _state.playerFactionId) continue;
      final d = worldPos.distanceTo(ship.position);
      if (d < selectionRadius && d < nearestPlayer) {
        nearestPlayer = d;
        tappedPlayer = ship;
      }
    }

    if (tappedPlayer != null) {
      _selectedShip = tappedPlayer;
      selectedShipNotifier.value = _selectedShip;
      return;
    }

    // Order phase: check pulse
    if (!_tempoSystem.isCommandPulseReady(_state)) return;

    // Check if tapping an enemy ship
    ShipState? tappedEnemy;
    double nearestEnemy = double.infinity;
    for (final ship in _state.ships.values) {
      if (!ship.isAlive || ship.factionId == _state.playerFactionId) continue;
      final d = worldPos.distanceTo(ship.position);
      if (d < selectionRadius && d < nearestEnemy) {
        nearestEnemy = d;
        tappedEnemy = ship;
      }
    }

    const int maxPending = 6;

    // Fleet mode: one tap commands all ships
    if (fleetMode) {
      if (tappedEnemy != null) {
        // Fleet attack order
        for (final ship in _state.ships.values) {
          if (!ship.isAlive || ship.factionId != _state.playerFactionId) continue;
          if (ship.pendingOrders.length >= maxPending) continue;
          _commandSystem.issueOrder(
            state: _state,
            targetShipId: ship.instanceId,
            orderType: OrderType.attackTarget,
            targetPosition: tappedEnemy.position.clone(),
            targetEnemyId: tappedEnemy.instanceId,
            registry: kShipDefinitions,
            targetSpeedFraction: selectedSpeed,
          );
        }
        _tempoSystem.advanceCommandPulse(_state);
        commandPulseReadyNotifier.value = false;
        final fs = _getPlayerFlagship();
        if (fs != null) _spawnOrderPulse(fs);
        playSound('order_click.ogg');
      } else {
        _issueFleetMoveTo(worldPos);
      }
      return;
    }

    // Individual ship mode
    if (_selectedShip == null || !_selectedShip!.isAlive) return;
    if (_selectedShip!.pendingOrders.length >= maxPending) return;

    if (tappedEnemy != null) {
      _commandSystem.issueOrder(
        state: _state,
        targetShipId: _selectedShip!.instanceId,
        orderType: OrderType.attackTarget,
        targetPosition: tappedEnemy.position.clone(),
        targetEnemyId: tappedEnemy.instanceId,
        registry: kShipDefinitions,
        targetSpeedFraction: selectedSpeed,
      );
    } else {
      _commandSystem.issueOrder(
        state: _state,
        targetShipId: _selectedShip!.instanceId,
        orderType: OrderType.moveTo,
        targetPosition: worldPos.clone(),
        registry: kShipDefinitions,
        targetSpeedFraction: selectedSpeed,
      );
    }
    _tempoSystem.advanceCommandPulse(_state);
    commandPulseReadyNotifier.value = false;
    _spawnOrderPulse(_selectedShip!);
    playSound('order_click.ogg');
  }

  /// Issues moveTo orders to all alive player ships, maintaining their current
  /// offsets from the flagship (preserves formation shape).
  void _issueFleetMoveTo(Vector2 tapPos) {
    final flagship = _getPlayerFlagship();
    if (flagship == null || !flagship.isAlive) return;

    const int maxPending = 6;
    for (final ship in _state.ships.values) {
      if (!ship.isAlive || ship.factionId != _state.playerFactionId) continue;
      if (ship.pendingOrders.length >= maxPending) continue;
      final offset = ship.position - flagship.position;
      _commandSystem.issueOrder(
        state: _state,
        targetShipId: ship.instanceId,
        orderType: OrderType.moveTo,
        targetPosition: tapPos + offset,
        registry: kShipDefinitions,
        targetSpeedFraction: selectedSpeed,
      );
    }
    _tempoSystem.advanceCommandPulse(_state);
    commandPulseReadyNotifier.value = false;
    _spawnOrderPulse(flagship);
    playSound('order_click.ogg');
  }

  /// Spawns a visual pulse along whichever path the order actually took.
  void _spawnOrderPulse(ShipState target) {
    final topology = _state.topologies[_state.playerFactionId];
    if (topology == null) return;
    final flagship = _state.ships[topology.flagship.shipInstanceId];
    if (flagship == null) return;

    final relayNodeId = target.assignedCommandNodeId;
    final relayNode = relayNodeId != null ? topology.nodes[relayNodeId] : null;
    final relay = relayNode != null ? _state.ships[relayNode.shipInstanceId] : null;

    final directDist = flagship.position.distanceTo(target.position);

    if (relay != null && relay.isAlive && relay.instanceId != flagship.instanceId) {
      final relayDist = flagship.position.distanceTo(relay.position) +
          relay.position.distanceTo(target.position);

      if (relayDist < directDist) {
        final leg1Dist = flagship.position.distanceTo(relay.position);
        final leg2Dist = relay.position.distanceTo(target.position);
        spawnTransitPulse(flagship.position, relay.position,
            (leg1Dist / 40.0).clamp(0.5, 8.0));
        spawnTransitPulse(relay.position, target.position,
            (leg2Dist / 40.0).clamp(0.3, 6.0));
        return;
      }
    }

    spawnTransitPulse(flagship.position, target.position,
        (directDist / 40.0).clamp(0.5, 10.0));
  }

  void togglePause() {
    if (_state.phase != BattlePhase.active) return;
    isPausedNotifier.value = !isPausedNotifier.value;
  }

  /// Cancel all pending and active orders for the selected ship.
  void cancelOrders() {
    if (!_isInitialized) return;
    if (_selectedShip == null || !_selectedShip!.isAlive) return;
    _selectedShip!.pendingOrders.clear();
    _selectedShip!.activeOrder = null;
  }

  @override
  void onScroll(PointerScrollInfo info) {
    if (!_isInitialized) return;
    final delta = info.scrollDelta.global.y;
    _renderer.adjustZoom(delta > 0 ? 0.9 : 1.1);
  }

  /// Issue a HOLD order to the selected ship (if pulse is ready).
  void issueHold() {
    if (!_isInitialized || _state.phase != BattlePhase.active) return;
    if (_selectedShip == null || !_selectedShip!.isAlive) return;
    if (!_tempoSystem.isCommandPulseReady(_state)) return;
    _commandSystem.issueOrder(
      state: _state,
      targetShipId: _selectedShip!.instanceId,
      orderType: OrderType.hold,
      registry: kShipDefinitions,
      targetSpeedFraction: selectedSpeed,
    );
    _tempoSystem.advanceCommandPulse(_state);
    commandPulseReadyNotifier.value = false;
    _spawnOrderPulse(_selectedShip!);
    playSound('order_click.ogg');
  }

  /// Issue a RETREAT order (move to own flagship position) to the selected ship.
  void issueRetreat() {
    if (!_isInitialized || _state.phase != BattlePhase.active) return;
    if (_selectedShip == null || !_selectedShip!.isAlive) return;
    if (!_tempoSystem.isCommandPulseReady(_state)) return;
    final playerTopology = _state.topologies[_state.playerFactionId];
    if (playerTopology == null) return;
    final flagship = _state.ships[playerTopology.flagship.shipInstanceId];
    if (flagship == null || !flagship.isAlive) return;
    _commandSystem.issueOrder(
      state: _state,
      targetShipId: _selectedShip!.instanceId,
      orderType: OrderType.moveTo,
      targetPosition: flagship.position.clone(),
      registry: kShipDefinitions,
      targetSpeedFraction: selectedSpeed,
    );
    _tempoSystem.advanceCommandPulse(_state);
    commandPulseReadyNotifier.value = false;
    _spawnOrderPulse(_selectedShip!);
    playSound('order_click.ogg');
  }

  void _checkWinLoss() {
    if (_state.phase != BattlePhase.active) return;

    // Lose: player flagship destroyed
    final playerTopology = _state.topologies[_state.playerFactionId];
    if (playerTopology != null) {
      final pFlag = _state.ships[playerTopology.flagship.shipInstanceId];
      if (pFlag != null && !pFlag.isAlive) {
        _endBattle(won: false);
        return;
      }
    }

    // Win: objective met
    final wc = _state.winCondition;
    if (wc == null) return;

    switch (wc.type) {
      case WinConditionType.destroyEnemyFlagship:
        if (wc.targetShipId != null) {
          final target = _state.ships[wc.targetShipId!];
          if (target != null && !target.isAlive) _endBattle(won: true);
        }
      case WinConditionType.destroyAllEnemies:
        if (_state.enemyShips.every((s) => !s.isAlive)) _endBattle(won: true);
      case WinConditionType.surviveUntilTime:
        if (wc.timeLimit != null && _state.battleTime >= wc.timeLimit!) {
          _endBattle(won: true);
        }
      case WinConditionType.custom:
        break;
    }
  }

  void _endBattle({required bool won}) {
    if (_state.phase != BattlePhase.active) return;
    _state.phase = won ? BattlePhase.won : BattlePhase.lost;
    battlePhaseNotifier.value = _state.phase;
    overlays.remove('hud');
    overlays.add(won ? 'win' : 'lose');
  }

  /// Spawns a visual transit pulse from [from] to [to] over [duration] seconds.
  void spawnTransitPulse(Vector2 from, Vector2 to, double duration) {
    transitPulses.add(TransitPulse(
      from: from.clone(),
      to: to.clone(),
      progress: 0.0,
      speed: 1.0 / duration,
    ));
  }

  void _advanceTransitPulses(double dt) {
    transitPulses.removeWhere((p) {
      p.progress += p.speed * dt;
      return p.progress >= 1.0;
    });
  }

  void _spawnExplosion(ShipState ship) {
    const baseColor = Color(0xFFFF8800);
    final factionColor = ship.factionId == _state.playerFactionId
        ? const Color(0xFF4A90D9)
        : const Color(0xFFD94A4A);
    final blended = Color.fromARGB(
      255,
      ((baseColor.r + factionColor.r) * 127.5).round(),
      ((baseColor.g + factionColor.g) * 127.5).round(),
      ((baseColor.b + factionColor.b) * 127.5).round(),
    );

    for (var i = 0; i < 16; i++) {
      final angle = _rng.nextDouble() * math.pi * 2;
      final speed = 60.0 + _rng.nextDouble() * 100.0;
      particles.add(BattleParticle(
        position: ship.position.clone(),
        velocity: Vector2(math.cos(angle) * speed, math.sin(angle) * speed),
        life: 1.0,
        color: blended,
        radius: 3.0 + _rng.nextDouble() * 4.0,
      ));
    }
    playSound('explosion.ogg');
  }

  void _advanceParticles(double dt) {
    particles.removeWhere((p) {
      p.life -= dt * 0.7;
      p.position.add(p.velocity * dt);
      p.radius *= 1.008;
      return p.life <= 0;
    });
  }

  /// Spawns a visual projectile when a ship fires (called via combat.onFire).
  void _spawnProjectile(Vector2 from, Vector2 to, bool isMissile) {
    final dir = to - from;
    final dist = dir.length;
    if (dist < 1.0) return;
    final speed = isMissile ? 300.0 : 800.0;
    final maxLife = isMissile ? 1.2 : 0.25;
    projectiles.add(Projectile(
      position: from.clone(),
      velocity: dir.normalized() * speed,
      life: (dist / speed).clamp(0.05, maxLife),
      color: isMissile ? const Color(0xFFFFCC44) : const Color(0xFF88CCFF),
      isMissile: isMissile,
    ));
  }

  void _advanceProjectiles(double dt) {
    projectiles.removeWhere((p) {
      p.life -= dt;
      p.position.add(p.velocity * dt);
      return p.life <= 0;
    });
  }

  ShipState? _getPlayerFlagship() {
    final topology = _state.topologies[_state.playerFactionId];
    if (topology == null) return null;
    return _state.ships[topology.flagship.shipInstanceId];
  }

  ShipRole _roleForShip(ShipState ship) {
    final topology = _state.topologies[ship.factionId];
    if (topology != null) {
      for (final node in topology.nodes.values) {
        if (node.shipInstanceId == ship.instanceId) {
          return node.isRoot ? ShipRole.flagship : ShipRole.commandRelay;
        }
      }
    }
    return kShipDefinitions[ship.dataId]?.role ?? ShipRole.lightEscort;
  }

  void playSound(String name) {
    if (!_audioReady) return;
    try {
      FlameAudio.play(name);
    } catch (_) {}
  }
}

/// A visual-only dot that travels along the command chain when an order is issued.
class TransitPulse {
  final Vector2 from;
  final Vector2 to;
  double progress; // 0.0 → 1.0
  final double speed; // progress units per second

  TransitPulse({
    required this.from,
    required this.to,
    required this.progress,
    required this.speed,
  });

  Vector2 get currentPos => from + (to - from) * progress;
}

/// A single particle in an explosion effect.
class BattleParticle {
  Vector2 position;
  Vector2 velocity;
  double life; // 1.0 → 0.0, dies at 0
  final Color color;
  double radius;

  BattleParticle({
    required this.position,
    required this.velocity,
    required this.life,
    required this.color,
    required this.radius,
  });
}

/// A visual-only projectile (energy bolt or missile).
class Projectile {
  Vector2 position;
  final Vector2 velocity;
  double life; // seconds remaining
  final Color color;
  final bool isMissile;

  Projectile({
    required this.position,
    required this.velocity,
    required this.life,
    required this.color,
    required this.isMissile,
  });
}
