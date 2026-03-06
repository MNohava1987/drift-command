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
import '../core/models/squad.dart';
import '../core/systems/kinematic_system.dart';
import '../core/systems/command_system.dart';
import '../core/systems/tempo_system.dart';
import '../core/systems/combat_system.dart';
import '../core/systems/squad_system.dart';
import '../core/systems/engagement_system.dart';
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
  final BattleState? initialState;

  BattleGame({
    this.scenarioAssetPath = 'assets/scenarios/scenario_001.json',
    this.carryDamage = false,
    this.startingDurabilityFractions,
    this.initialState,
  });

  // ── Systems ──────────────────────────────────────────────────────────────
  final _tempoSystem = TempoSystem();
  final _commandSystem = CommandSystem();
  final _squadSystem = SquadSystem();
  late final KinematicSystem _kinematics;
  late final CombatSystem _combat;
  late final DoctrineAI _ai;

  // ── State ────────────────────────────────────────────────────────────────
  late BattleState _state;
  bool _isInitialized = false;
  SquadState? _selectedSquad;
  late BattlefieldRenderer _renderer;

  /// Approach speed for the next issued order: 0.25 / 0.5 / 1.0
  double selectedSpeed = 0.5;

  /// Simulation time multiplier. 0.0 = planning freeze, 1.0 = real time.
  double _timeScale = 0.0;

  /// Visual-only transit pulses.
  final List<TransitPulse> transitPulses = [];

  /// Particle explosions (visual only).
  final List<BattleParticle> particles = [];

  /// Visual projectiles — cosmetic only, damage is still instant.
  final List<Projectile> projectiles = [];

  final _rng = math.Random();
  double _weaponSoundCooldown = 0.0;
  bool _audioReady = false;

  // ── HUD notifiers (listened to by Flutter widgets) ───────────────────────
  final selectedSquadNotifier = ValueNotifier<SquadState?>(null);
  final battlePhaseNotifier = ValueNotifier<BattlePhase>(BattlePhase.setup);
  final battleTimeTextNotifier = ValueNotifier<String>('0:00');
  final isPausedNotifier = ValueNotifier<bool>(false);
  final timeScaleNotifier = ValueNotifier<double>(0.0);

  // ── Public accessors ─────────────────────────────────────────────────────
  BattleState get battleState => _state;
  BattleState? get battleStateOrNull => _isInitialized ? _state : null;
  SquadState? get selectedSquadState => _selectedSquad;

  @override
  Future<void> onLoad() async {
    _kinematics = KinematicSystem(shipDataRegistry: kShipDefinitions);
    _combat = CombatSystem(shipDataRegistry: kShipDefinitions);
    _combat.onFire = _spawnProjectile;
    final engagementSystem = EngagementSystem(
      commandSystem: _commandSystem,
      registry: kShipDefinitions,
    );
    _ai = DoctrineAI(
      commandSystem: _commandSystem,
      engagementSystem: engagementSystem,
      registry: kShipDefinitions,
    );

    if (initialState != null) {
      _state = initialState!;
    } else {
      final jsonStr = await rootBundle.loadString(scenarioAssetPath);
      final jsonMap = jsonDecode(jsonStr) as Map<String, dynamic>;
      _state = ScenarioLoader.fromJson(
        jsonMap,
        kShipDefinitions,
        carryDamage: carryDamage,
        startingDurabilityFractions: startingDurabilityFractions,
      );
    }

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
    timeScaleNotifier.value = 0.0;
    overlays.add('hud');
  }

  void setTimeScale(double scale) {
    _timeScale = scale;
    timeScaleNotifier.value = scale;
  }

  void engageBattle() {
    if (_timeScale == 0.0) setTimeScale(1.0);
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
        allShips: _state.ships,
      );
      _squadSystem.update(_state);

      final wasAlive = {for (final e in _state.ships.entries) e.key: e.value.isAlive};
      _combat.update(_state, scaledDt);

      for (final ship in _state.ships.values) {
        if (wasAlive[ship.instanceId] == true && !ship.isAlive) {
          _spawnExplosion(ship);
        }
      }

      if (_weaponSoundCooldown <= 0) {
        final combatHappened = _state.ships.values.any((attacker) {
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

    // Tap a player ship → select its squad
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
      final squadId = tappedPlayer.squadId;
      _selectedSquad = squadId != null ? _state.squads[squadId] : null;
      selectedSquadNotifier.value = _selectedSquad;
      return;
    }

    // No squad selected — nothing to order
    if (_selectedSquad == null) return;

    // Tap an enemy → attack order on squad
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

    if (tappedEnemy != null) {
      _commandSystem.issueSquadOrder(
        state: _state,
        squadId: _selectedSquad!.squadId,
        orderType: OrderType.attackTarget,
        targetPosition: tappedEnemy.position.clone(),
        targetEnemyId: tappedEnemy.instanceId,
        targetSpeedFraction: selectedSpeed,
      );
    } else {
      // Tap empty space → move squad
      _commandSystem.issueSquadOrder(
        state: _state,
        squadId: _selectedSquad!.squadId,
        orderType: OrderType.moveTo,
        targetPosition: worldPos.clone(),
        targetSpeedFraction: selectedSpeed,
      );
    }

    _spawnOrderPulse(_selectedSquad!);
    playSound('order_click.ogg');
  }

  /// Issue a HOLD order to the selected squad.
  void issueHold() {
    if (!_isInitialized || _state.phase != BattlePhase.active) return;
    if (_selectedSquad == null) return;
    _commandSystem.issueSquadOrder(
      state: _state,
      squadId: _selectedSquad!.squadId,
      orderType: OrderType.hold,
    );
    _spawnOrderPulse(_selectedSquad!);
    playSound('order_click.ogg');
  }

  /// Issue a RETREAT order to the selected squad — moves toward player flagship.
  void issueRetreat() {
    if (!_isInitialized || _state.phase != BattlePhase.active) return;
    if (_selectedSquad == null) return;
    final flagship = _state.playerFlagship;
    _commandSystem.issueSquadOrder(
      state: _state,
      squadId: _selectedSquad!.squadId,
      orderType: OrderType.retreat,
      targetPosition: flagship?.position.clone(),
    );
    _spawnOrderPulse(_selectedSquad!);
    playSound('order_click.ogg');
  }

  /// Cancel the selected squad's active order and all member ship orders.
  void cancelOrders() {
    if (!_isInitialized) return;
    if (_selectedSquad == null) return;
    _selectedSquad!.activeOrder = null;
    for (final id in _selectedSquad!.shipInstanceIds) {
      _state.ships[id]?.activeOrder = null;
    }
  }

  /// Update the engagement mode for a squad.
  void setEngagementMode(String squadId, EngagementMode mode) {
    _state.squads[squadId]?.engagementMode = mode;
  }

  void togglePause() {
    if (_state.phase != BattlePhase.active) return;
    isPausedNotifier.value = !isPausedNotifier.value;
  }

  @override
  void onScroll(PointerScrollInfo info) {
    if (!_isInitialized) return;
    final delta = info.scrollDelta.global.y;
    _renderer.adjustZoom(delta > 0 ? 0.9 : 1.1);
  }

  void _checkWinLoss() {
    if (_state.phase != BattlePhase.active) return;

    // Lose: player flagship destroyed
    final playerFlag = _state.playerFlagship;
    if (playerFlag != null && !playerFlag.isAlive) {
      _endBattle(won: false);
      return;
    }

    final wc = _state.winCondition;
    if (wc == null) return;

    switch (wc.type) {
      case WinConditionType.destroyEnemyFlagship:
        if (wc.targetShipId != null) {
          final target = _state.ships[wc.targetShipId!];
          if (target != null && !target.isAlive) _endBattle(won: true);
        } else {
          // Fallback: use tracked enemy flagship
          final ef = _state.enemyFlagship;
          if (ef != null && !ef.isAlive) _endBattle(won: true);
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

  /// Spawns a visual transit pulse from the player flagship to the squad centroid.
  void _spawnOrderPulse(SquadState squad) {
    final flagship = _state.playerFlagship;
    if (flagship == null) return;
    final dist = flagship.position.distanceTo(squad.centroid);
    spawnTransitPulse(
      flagship.position,
      squad.centroid,
      (dist / 40.0).clamp(0.5, 10.0),
    );
  }

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

  void playSound(String name) {
    if (!_audioReady) return;
    try {
      FlameAudio.play(name);
    } catch (_) {}
  }
}

/// A visual-only dot that travels from flagship to target when an order is issued.
class TransitPulse {
  final Vector2 from;
  final Vector2 to;
  double progress;
  final double speed;

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
  double life;
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
  double life;
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
