import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app smoke test — MaterialApp renders', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('Drift Command'))),
    );
    expect(find.text('Drift Command'), findsOneWidget);
  });
}
