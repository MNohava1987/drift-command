import 'package:drift_command/core/models/command_node.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds a 3-node topology: flagship → relay → [leaf1, leaf2]
CommandTopology _makeTopology() {
  return CommandTopology(
    factionId: 0,
    flagshipNodeId: 'flagship_node',
    nodes: {
      'flagship_node': CommandNode(
        nodeId: 'flagship_node',
        shipInstanceId: 'p_flagship',
        type: CommandNodeType.flagship,
        childNodeIds: ['relay_node'],
      ),
      'relay_node': CommandNode(
        nodeId: 'relay_node',
        shipInstanceId: 'p_relay',
        type: CommandNodeType.relay,
        parentNodeId: 'flagship_node',
        assignedCombatShipIds: ['p_heavy', 'p_escort'],
      ),
    },
  );
}

void main() {
  group('CommandTopology.isConnected', () {
    test('flagship is connected when alive', () {
      final topo = _makeTopology();
      final alive = {'p_flagship': true, 'p_relay': true, 'p_heavy': true, 'p_escort': true};
      expect(topo.isConnected('p_flagship', alive), isTrue);
    });

    test('relay is connected when flagship and relay alive', () {
      final topo = _makeTopology();
      final alive = {'p_flagship': true, 'p_relay': true, 'p_heavy': true, 'p_escort': true};
      expect(topo.isConnected('p_relay', alive), isTrue);
    });

    test('relay is disconnected when flagship dead', () {
      final topo = _makeTopology();
      final alive = {'p_flagship': false, 'p_relay': true, 'p_heavy': true, 'p_escort': true};
      expect(topo.isConnected('p_relay', alive), isFalse);
    });

    test('leaf ship is connected via assignedCommandNodeId when relay alive', () {
      final topo = _makeTopology();
      final alive = {'p_flagship': true, 'p_relay': true, 'p_heavy': true, 'p_escort': true};
      expect(
        topo.isConnected('p_heavy', alive, assignedCommandNodeId: 'relay_node'),
        isTrue,
      );
    });

    test('leaf ship is disconnected when relay dead', () {
      final topo = _makeTopology();
      final alive = {'p_flagship': true, 'p_relay': false, 'p_heavy': true, 'p_escort': true};
      expect(
        topo.isConnected('p_heavy', alive, assignedCommandNodeId: 'relay_node'),
        isFalse,
      );
    });

    test('leaf ship is disconnected when flagship dead (relay alive)', () {
      final topo = _makeTopology();
      final alive = {'p_flagship': false, 'p_relay': true, 'p_heavy': true, 'p_escort': true};
      expect(
        topo.isConnected('p_heavy', alive, assignedCommandNodeId: 'relay_node'),
        isFalse,
      );
    });

    test('leaf ship without assignedCommandNodeId returns false', () {
      final topo = _makeTopology();
      final alive = {'p_flagship': true, 'p_relay': true, 'p_heavy': true};
      expect(topo.isConnected('p_heavy', alive), isFalse);
    });
  });
}
