import 'dart:math' as math;
import 'package:flame/components.dart';
import '../models/ship_data.dart';
import '../models/battle_state.dart';
import '../systems/command_system.dart';

/// Doctrine-driven AI for enemy factions.
/// Re-evaluates on an interval scaled to the current tempo band.
class DoctrineAI {
  final CommandSystem commandSystem;
  final Map<String, ShipData> registry;
  final math.Random _rng;

  double _nextAIUpdate = 0;

  static const Map<TempoBand, double> _aiInterval = {
    TempoBand.distant: 15.0,
    TempoBand.contact: 7.0,
    TempoBand.engaged: 3.0,
  };

  DoctrineAI({
    required this.commandSystem,
    required this.registry,
    math.Random? rng,
  }) : _rng = rng ?? math.Random();

  void update(BattleState state, double dt) {
    if (state.battleTime < _nextAIUpdate) return;
    _nextAIUpdate = state.battleTime + (_aiInterval[state.tempoBand] ?? 3.0);

    final factionIds = state.ships.values
        .map((s) => s.factionId)
        .toSet()
        .where((id) => id != state.playerFactionId);

    for (final factionId in factionIds) {
      _runFactionAI(state, factionId);
    }
  }

  void _runFactionAI(BattleState state, int factionId) {
    final myShips = state.ships.values
        .where((s) => s.factionId == factionId && s.isAlive)
        .toList();

    final playerShips = state.playerShips.where((s) => s.isAlive).toList();
    if (playerShips.isEmpty) return;

    final playerFlagship = state.playerFlagship?.isAlive == true
        ? state.playerFlagship
        : playerShips.firstOrNull;

    final myFlagship = _findFlagship(state, factionId);
    final posture = state.factionPostures[factionId] ?? AiPosture.aggressive;

    for (final ship in myShips) {
      final data = registry[ship.dataId];
      if (data == null) continue;

      ship.shipMode = (posture == AiPosture.aggressive || posture == AiPosture.flanking)
          ? ShipMode.attack
          : ShipMode.defensive;

      _applyShipDoctrine(
        state: state,
        ship: ship,
        data: data,
        factionId: factionId,
        playerShips: playerShips,
        playerFlagship: playerFlagship,
        myFlagship: myFlagship,
        posture: posture,
      );
    }
  }

  void _applyShipDoctrine({
    required BattleState state,
    required ShipState ship,
    required ShipData data,
    required int factionId,
    required List<ShipState> playerShips,
    required ShipState? playerFlagship,
    required ShipState? myFlagship,
    required AiPosture posture,
  }) {
    if (_applyPostureOverride(ship, data, posture, state, playerShips, playerFlagship)) return;

    switch (data.role) {
      case ShipRole.flagship:
        if (_isThreatened(ship, state)) {
          _issueRetreat(state, ship, myFlagship);
        }

      // commandRelay treated as light escort — screens the flagship
      case ShipRole.commandRelay:
      case ShipRole.lightEscort:
        if (myFlagship != null) {
          final screenPos = myFlagship.position +
              Vector2(_rng.nextDouble() * 60 - 30, _rng.nextDouble() * 60 - 30);
          _issueMove(state, ship, screenPos);
        }

      case ShipRole.heavyLine:
        final target = playerFlagship ?? playerShips.first;
        _issueAttack(state, ship, target);

      case ShipRole.fastRaider:
        if (playerShips.isNotEmpty) {
          _issueAttack(state, ship, playerShips.first);
        }

      case ShipRole.strikeCarrier:
        if (playerShips.isNotEmpty) {
          final target = playerShips.first;
          final dist = ship.position.distanceTo(target.position);
          if (dist > 200) {
            _issueAttack(state, ship, target);
          } else {
            _issueRetreat(state, ship, myFlagship);
          }
        }
    }
  }

  bool _applyPostureOverride(
    ShipState ship,
    ShipData data,
    AiPosture posture,
    BattleState state,
    List<ShipState> playerShips,
    ShipState? playerFlagship,
  ) {
    switch (posture) {
      case AiPosture.aggressive:
        return false;

      case AiPosture.defensive:
        final nearEnemy = playerShips.any(
          (p) => p.position.distanceTo(ship.position) <= data.weaponRange,
        );
        if (!nearEnemy) {
          _issueHold(state, ship);
        }
        return true;

      case AiPosture.flanking:
        if (data.role == ShipRole.heavyLine || data.role == ShipRole.flagship) {
          if (playerFlagship != null) {
            _issueAttack(state, ship, playerFlagship);
          } else if (playerShips.isNotEmpty) {
            _issueAttack(state, ship, playerShips.first);
          }
        } else if (playerFlagship != null) {
          final toFlagship = playerFlagship.position - ship.position;
          final perp = Vector2(-toFlagship.y, toFlagship.x).normalized() *
              (data.weaponRange * 0.8);
          final flankPos = playerFlagship.position + perp;
          _issueMove(state, ship, flankPos);
        } else if (playerShips.isNotEmpty) {
          _issueAttack(state, ship, playerShips.first);
        }
        return true;

      case AiPosture.holdAndFire:
        _issueHold(state, ship);
        return true;
    }
  }

  bool _isThreatened(ShipState ship, BattleState state) {
    return state.playerShips.any(
      (p) => p.isAlive && p.position.distanceTo(ship.position) < 80,
    );
  }

  ShipState? _findFlagship(BattleState state, int factionId) {
    return state.ships.values.firstWhere(
      (s) => s.factionId == factionId && s.isAlive &&
          (registry[s.dataId]?.role == ShipRole.flagship),
      orElse: () => state.ships.values.firstWhere(
        (s) => s.factionId == factionId && s.isAlive,
        orElse: () => state.ships.values.first,
      ),
    );
  }

  void _issueMove(BattleState state, ShipState ship, Vector2 target) {
    commandSystem.issueOrder(
      state: state,
      targetShipId: ship.instanceId,
      orderType: OrderType.moveTo,
      targetPosition: target,
    );
  }

  void _issueAttack(BattleState state, ShipState ship, ShipState target) {
    commandSystem.issueOrder(
      state: state,
      targetShipId: ship.instanceId,
      orderType: OrderType.attackTarget,
      targetPosition: target.position,
      targetEnemyId: target.instanceId,
    );
  }

  void _issueRetreat(BattleState state, ShipState ship, ShipState? myFlagship) {
    commandSystem.issueOrder(
      state: state,
      targetShipId: ship.instanceId,
      orderType: OrderType.retreat,
      targetPosition: myFlagship?.position,
    );
  }

  void _issueHold(BattleState state, ShipState ship) {
    commandSystem.issueOrder(
      state: state,
      targetShipId: ship.instanceId,
      orderType: OrderType.hold,
    );
  }
}
