import 'dart:math' as math;
import 'package:flame/components.dart';
import '../models/ship_data.dart';
import '../models/battle_state.dart';
import '../systems/command_system.dart';

/// Doctrine-driven AI for enemy factions.
/// The AI does not "cheat" — it works through the same command system
/// the player uses, including propagation delays.
class DoctrineAI {
  final CommandSystem commandSystem;
  final Map<String, ShipData> registry;
  final math.Random _rng;

  double _nextAIUpdate = 0;

  // AI re-evaluation interval mirrors the tempo band pulse windows so the enemy
  // faces the same command pacing as the player (distant=15s, contact=7s, engaged=3s).
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

    for (final factionId in state.topologies.keys) {
      if (factionId == state.playerFactionId) continue;
      _runFactionAI(state, factionId);
    }
  }

  void _runFactionAI(BattleState state, int factionId) {
    final topology = state.topologies[factionId];
    if (topology == null) return;

    final myShips = state.ships.values
        .where((s) => s.factionId == factionId && s.isAlive)
        .toList();

    final playerShips = state.playerShips.where((s) => s.isAlive).toList();
    if (playerShips.isEmpty) return;

    final playerFlagship = _findFlagship(state, state.playerFactionId);
    final myFlagship = _findFlagship(state, factionId);
    final posture = _postureFor(factionId, state);

    for (final ship in myShips) {
      final data = registry[ship.dataId];
      if (data == null) continue;

      // Sync ship mode to posture
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

  AiPosture _postureFor(int factionId, BattleState state) {
    return state.factionPostures[factionId] ?? AiPosture.aggressive;
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
        // Flagship stays back, protects itself
        if (_isThreatened(ship, state)) {
          _issueRetreat(state, ship, factionId);
        }

      case ShipRole.commandRelay:
        // Try to stay midfield to extend command range
        if (myFlagship != null) {
          final midpoint = (myFlagship.position + _nearestPlayerPosition(ship, playerShips)) / 2;
          _issueMove(state, ship, factionId, midpoint);
        }

      case ShipRole.heavyLine:
        // Advance on player flagship if visible, else nearest player
        final target = playerFlagship ?? playerShips.first;
        _issueAttack(state, ship, factionId, target);

      case ShipRole.lightEscort:
        // Screen the flagship or nearest heavy
        if (myFlagship != null) {
          final screenPos = myFlagship.position + Vector2(_rng.nextDouble() * 60 - 30, _rng.nextDouble() * 60 - 30);
          _issueMove(state, ship, factionId, screenPos);
        }

      case ShipRole.fastRaider:
        // Try to flank or attack relay ships
        final relayTarget = _findPlayerRelay(state);
        if (relayTarget != null) {
          _issueAttack(state, ship, factionId, relayTarget);
        } else if (playerShips.isNotEmpty) {
          _issueAttack(state, ship, factionId, playerShips.first);
        }

      case ShipRole.strikeCarrier:
        // Stay at range, attack from distance
        if (playerShips.isNotEmpty) {
          final target = playerShips.first;
          final dist = ship.position.distanceTo(target.position);
          if (dist > 200) {
            _issueAttack(state, ship, factionId, target);
          } else {
            _issueRetreat(state, ship, factionId);
          }
        }
    }
  }

  /// Returns true if posture override handled this ship (skip role dispatch).
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
        // Default role-based dispatch handles aggressive
        return false;

      case AiPosture.defensive:
        // Flagship never retreats; all ships HOLD unless enemy in weapon range
        final nearEnemy = playerShips.any(
          (p) => p.position.distanceTo(ship.position) <= data.weaponRange,
        );
        if (!nearEnemy) {
          _issueHold(state, ship, ship.factionId);
        }
        return true;

      case AiPosture.flanking:
        // Raiders and escorts target perpendicular to player flagship; heavies push straight
        if (data.role == ShipRole.heavyLine || data.role == ShipRole.flagship) {
          if (playerFlagship != null) {
            _issueAttack(state, ship, ship.factionId, playerFlagship);
          } else if (playerShips.isNotEmpty) {
            _issueAttack(state, ship, ship.factionId, playerShips.first);
          }
        } else if (playerFlagship != null) {
          // Perpendicular position relative to player flagship
          final toFlagship = playerFlagship.position - ship.position;
          final perp = Vector2(-toFlagship.y, toFlagship.x).normalized() *
              (data.weaponRange * 0.8);
          final flankPos = playerFlagship.position + perp;
          _issueMove(state, ship, ship.factionId, flankPos);
        } else if (playerShips.isNotEmpty) {
          _issueAttack(state, ship, ship.factionId, playerShips.first);
        }
        return true;

      case AiPosture.holdAndFire:
        // All ships HOLD and let CombatSystem handle auto-fire
        _issueHold(state, ship, ship.factionId);
        return true;
    }
  }

  bool _isThreatened(ShipState ship, BattleState state) {
    // Check whether any player ship is within threat range of this (enemy) ship.
    return state.playerShips.any((p) =>
        p.isAlive && p.position.distanceTo(ship.position) < 80);
  }

  Vector2 _nearestPlayerPosition(ShipState from, List<ShipState> players) {
    return players.fold<ShipState>(
      players.first,
      (nearest, s) => s.position.distanceTo(from.position) < nearest.position.distanceTo(from.position) ? s : nearest,
    ).position;
  }

  ShipState? _findFlagship(BattleState state, int factionId) {
    final topology = state.topologies[factionId];
    if (topology == null) return null;
    final flagshipShipId = topology.flagship.shipInstanceId;
    return state.ships[flagshipShipId];
  }

  ShipState? _findPlayerRelay(BattleState state) {
    final playerTopology = state.topologies[state.playerFactionId];
    if (playerTopology == null) return null;
    for (final node in playerTopology.nodes.values) {
      if (node.isRelay) {
        final ship = state.ships[node.shipInstanceId];
        if (ship != null && ship.isAlive) return ship;
      }
    }
    return null;
  }

  void _issueMove(BattleState state, ShipState ship, int factionId, Vector2 target) {
    commandSystem.issueOrder(
      state: state,
      targetShipId: ship.instanceId,
      orderType: OrderType.moveTo,
      targetPosition: target,
      registry: registry,
    );
  }

  void _issueAttack(BattleState state, ShipState ship, int factionId, ShipState target) {
    commandSystem.issueOrder(
      state: state,
      targetShipId: ship.instanceId,
      orderType: OrderType.attackTarget,
      targetPosition: target.position,
      targetEnemyId: target.instanceId,
      registry: registry,
    );
  }

  void _issueRetreat(BattleState state, ShipState ship, int factionId) {
    commandSystem.issueOrder(
      state: state,
      targetShipId: ship.instanceId,
      orderType: OrderType.retreat,
      registry: registry,
    );
  }

  void _issueHold(BattleState state, ShipState ship, int factionId) {
    commandSystem.issueOrder(
      state: state,
      targetShipId: ship.instanceId,
      orderType: OrderType.hold,
      registry: registry,
    );
  }
}
