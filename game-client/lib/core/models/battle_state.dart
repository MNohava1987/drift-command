import 'ship_data.dart';
import 'command_node.dart';

enum TempoBand { distant, contact, engaged }

enum AiPosture { aggressive, defensive, flanking, holdAndFire }

enum BattlePhase { setup, active, won, lost }

/// Complete snapshot of a battle at a given simulation time.
/// All game logic reads from and writes to this structure.
class BattleState {
  double battleTime;          // total elapsed battle time in seconds
  BattlePhase phase;

  final Map<String, ShipState> ships;           // keyed by instanceId
  final Map<int, CommandTopology> topologies;   // keyed by factionId

  TempoBand tempoBand;
  double nextCommandPulse;    // battle time when the next command window opens
  double commandWindowEnd;    // battle time when the current command window closes
  //   double.infinity = window is open with no scheduled close (game start)

  final int playerFactionId;
  final String objectiveDescription;
  WinCondition? winCondition;
  final Map<int, AiPosture> factionPostures;

  BattleState({
    required this.playerFactionId,
    required this.objectiveDescription,
    required this.ships,
    required this.topologies,
    this.battleTime = 0.0,
    this.phase = BattlePhase.setup,
    this.tempoBand = TempoBand.distant,
    this.nextCommandPulse = 0.0,
    this.commandWindowEnd = double.infinity,
    this.winCondition,
    this.factionPostures = const {},
  });

  List<ShipState> get playerShips =>
      ships.values.where((s) => s.factionId == playerFactionId).toList();

  List<ShipState> get enemyShips =>
      ships.values.where((s) => s.factionId != playerFactionId).toList();

  List<ShipState> get aliveShips =>
      ships.values.where((s) => s.isAlive).toList();

  Map<String, bool> get aliveMap =>
      {for (final s in ships.values) s.instanceId: s.isAlive};
}

/// Describes win/loss conditions for a scenario.
class WinCondition {
  final WinConditionType type;
  final String? targetShipId;     // for 'destroy flagship'
  final double? timeLimit;        // for 'survive X seconds'

  const WinCondition({required this.type, this.targetShipId, this.timeLimit});
}

enum WinConditionType {
  destroyEnemyFlagship,
  destroyAllEnemies,
  surviveUntilTime,
  custom,
}
