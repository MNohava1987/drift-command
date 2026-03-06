import 'dart:convert';

import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart';

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

  BattleGame({
    this.scenarioAssetPath = 'assets/scenarios/scenario_001.json',
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

  /// Simulation time multiplier. 1.0 = real time.
  double _timeScale = 1.0;

  /// Visual-only transit pulses. Each entry is [fromPos, toPos, progress 0→1, speed].
  final List<TransitPulse> transitPulses = [];

  // ── HUD notifiers (listened to by Flutter widgets) ───────────────────────
  final tempoBandNotifier = ValueNotifier<TempoBand>(TempoBand.distant);
  final selectedShipNotifier = ValueNotifier<ShipState?>(null);
  final battlePhaseNotifier = ValueNotifier<BattlePhase>(BattlePhase.setup);
  final battleTimeTextNotifier = ValueNotifier<String>('0:00');
  final commandPulseReadyNotifier = ValueNotifier<bool>(false);
  final isPausedNotifier = ValueNotifier<bool>(false);
  final timeScaleNotifier = ValueNotifier<double>(1.0);

  // ── Public accessors ─────────────────────────────────────────────────────
  BattleState get battleState => _state;
  BattleState? get battleStateOrNull => _isInitialized ? _state : null;
  ShipState? get selectedShipState => _selectedShip;

  @override
  Future<void> onLoad() async {
    _kinematics = KinematicSystem(shipDataRegistry: kShipDefinitions);
    _combat = CombatSystem(shipDataRegistry: kShipDefinitions);
    _ai = DoctrineAI(commandSystem: _commandSystem, registry: kShipDefinitions);

    final jsonStr = await rootBundle.loadString(scenarioAssetPath);
    final jsonMap = jsonDecode(jsonStr) as Map<String, dynamic>;
    _state = ScenarioLoader.fromJson(jsonMap, kShipDefinitions);

    _renderer = BattlefieldRenderer(this);
    await add(_renderer);

    _isInitialized = true;
    _state.phase = BattlePhase.active;
    battlePhaseNotifier.value = BattlePhase.active;
    overlays.add('hud');
  }

  /// Set simulation time multiplier. 0.5 = half speed, 4.0 = 4× speed.
  void setTimeScale(double scale) {
    _timeScale = scale;
    timeScaleNotifier.value = scale;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!_isInitialized) return;
    if (_state.phase != BattlePhase.active) return;

    if (isPausedNotifier.value) return;
    final scaledDt = dt * _timeScale;
    _tempoSystem.update(_state, scaledDt);
    _ai.update(_state, scaledDt);

    final aliveShips = _state.ships.values.where((s) => s.isAlive).toList();
    _kinematics.update(
      aliveShips,
      scaledDt,
      battleTime: _state.battleTime,
      allShips: _state.ships,
    );

    _combat.update(_state, scaledDt);
    _checkWinLoss();

    _advanceTransitPulses(scaledDt);

    // Refresh HUD notifiers
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
    const double selectionRadius = 30.0;

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

    // No player ship tapped — issue order to selected ship
    if (_selectedShip == null || !_selectedShip!.isAlive) return;
    if (!_tempoSystem.isCommandPulseReady(_state)) return;

    // Check if tapping an enemy ship → attack order
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
  }

  /// Spawns a visual pulse along whichever path the order actually took
  /// (direct flagship→target if shorter, or flagship→relay→target if relay saves distance).
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
        // Relay path is shorter — two-leg pulse
        final leg1Dist = flagship.position.distanceTo(relay.position);
        final leg2Dist = relay.position.distanceTo(target.position);
        spawnTransitPulse(flagship.position, relay.position,
            (leg1Dist / 20.0).clamp(0.5, 8.0));
        spawnTransitPulse(relay.position, target.position,
            (leg2Dist / 20.0).clamp(0.3, 6.0));
        return;
      }
    }

    // Direct path (closer or no relay)
    spawnTransitPulse(flagship.position, target.position,
        (directDist / 20.0).clamp(0.5, 10.0));
  }

  void togglePause() {
    if (_state.phase != BattlePhase.active) return;
    isPausedNotifier.value = !isPausedNotifier.value;
  }

  /// Cancel all pending and active orders for the selected ship.
  /// Ship coasts on current velocity until a new order arrives.
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
