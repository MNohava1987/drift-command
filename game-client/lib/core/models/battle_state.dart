import 'ship_data.dart';
import 'squad.dart';

enum TempoBand { distant, contact, engaged }

enum AiPosture { aggressive, defensive, flanking, holdAndFire }

enum BattlePhase { setup, active, won, lost }

/// Complete snapshot of a battle at a given simulation time.
/// All game logic reads from and writes to this structure.
class BattleState {
  double battleTime;        // total elapsed battle time in seconds
  BattlePhase phase;

  final Map<String, ShipState> ships; // keyed by instanceId
  final Map<String, SquadState> squads; // keyed by squadId
  final int playerBudget;
  final List<SquadType> availableSquadTypes;

  /// Instance ID of the player's flagship. Used for win/loss and retreat orders.
  final String playerFlagshipId;

  /// Instance ID of the primary enemy flagship (win condition target).
  final String? enemyFlagshipId;

  /// Current tempo band — used by DoctrineAI to set update interval.
  TempoBand tempoBand;

  final int playerFactionId;
  final String objectiveDescription;
  WinCondition? winCondition;
  final Map<int, AiPosture> factionPostures;

  BattleState({
    required this.playerFactionId,
    required this.objectiveDescription,
    required this.ships,
    required this.playerFlagshipId,
    this.enemyFlagshipId,
    this.squads = const {},
    this.playerBudget = 0,
    this.availableSquadTypes = const [],
    this.battleTime = 0.0,
    this.phase = BattlePhase.setup,
    this.tempoBand = TempoBand.distant,
    this.winCondition,
    this.factionPostures = const {},
  });

  List<ShipState> get playerShips =>
      ships.values.where((s) => s.factionId == playerFactionId).toList();

  List<ShipState> get enemyShips =>
      ships.values.where((s) => s.factionId != playerFactionId).toList();

  List<ShipState> get aliveShips =>
      ships.values.where((s) => s.isAlive).toList();

  ShipState? get playerFlagship => ships[playerFlagshipId];

  ShipState? get enemyFlagship =>
      enemyFlagshipId != null ? ships[enemyFlagshipId] : null;

  Iterable<SquadState> get playerSquads =>
      squads.values.where((sq) => sq.factionId == playerFactionId);

  Iterable<SquadState> get enemySquads =>
      squads.values.where((sq) => sq.factionId != playerFactionId);

  bool squadIsAlive(SquadState squad) =>
      squad.shipInstanceIds.any((id) => ships[id]?.isAlive == true);

  SquadState? get playerFlagshipSquad => squads.values
      .where((sq) => sq.factionId == playerFactionId && sq.type == SquadType.flagship)
      .firstOrNull;
}

/// Describes win/loss conditions for a scenario.
class WinCondition {
  final WinConditionType type;
  final String? targetShipId;   // for 'destroyEnemyFlagship'
  final double? timeLimit;      // for 'surviveUntilTime'

  const WinCondition({required this.type, this.targetShipId, this.timeLimit});
}

enum WinConditionType {
  destroyEnemyFlagship,
  destroyAllEnemies,
  surviveUntilTime,
  custom,
}
