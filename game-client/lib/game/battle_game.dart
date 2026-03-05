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
class BattleGame extends FlameGame with TapCallbacks {
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

  // ── HUD notifiers (listened to by Flutter widgets) ───────────────────────
  final tempoBandNotifier = ValueNotifier<TempoBand>(TempoBand.distant);
  final selectedShipNotifier = ValueNotifier<ShipState?>(null);
  final battlePhaseNotifier = ValueNotifier<BattlePhase>(BattlePhase.setup);
  final battleTimeTextNotifier = ValueNotifier<String>('0:00');

  // ── Public accessors ─────────────────────────────────────────────────────
  BattleState get battleState => _state;
  BattleState? get battleStateOrNull => _isInitialized ? _state : null;
  ShipState? get selectedShipState => _selectedShip;

  @override
  Future<void> onLoad() async {
    _kinematics = KinematicSystem(shipDataRegistry: kShipDefinitions);
    _combat = CombatSystem(shipDataRegistry: kShipDefinitions);
    _ai = DoctrineAI(commandSystem: _commandSystem, registry: kShipDefinitions);

    final jsonStr = await rootBundle
        .loadString('assets/scenarios/scenario_001.json');
    final jsonMap = jsonDecode(jsonStr) as Map<String, dynamic>;
    _state = ScenarioLoader.fromJson(jsonMap, kShipDefinitions);

    _renderer = BattlefieldRenderer(this);
    await add(_renderer);

    _isInitialized = true;
    _state.phase = BattlePhase.active;
    battlePhaseNotifier.value = BattlePhase.active;
    overlays.add('hud');
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!_isInitialized) return;
    if (_state.phase != BattlePhase.active) return;

    _tempoSystem.update(_state, dt);
    _ai.update(_state, dt);

    final aliveShips = _state.ships.values.where((s) => s.isAlive).toList();
    _kinematics.update(
      aliveShips,
      dt,
      battleTime: _state.battleTime,
      allShips: _state.ships,
    );

    _combat.update(_state, dt);
    _checkWinLoss();

    // Refresh HUD notifiers
    tempoBandNotifier.value = _state.tempoBand;
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
      );
    } else {
      _commandSystem.issueOrder(
        state: _state,
        targetShipId: _selectedShip!.instanceId,
        orderType: OrderType.moveTo,
        targetPosition: worldPos.clone(),
        registry: kShipDefinitions,
      );
    }
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
}
