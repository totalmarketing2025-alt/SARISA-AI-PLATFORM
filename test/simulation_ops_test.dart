import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sarisa/features/simulation/screens/simulation_ops_page.dart';

void main() {
  testWidgets('simulator starts read-only and exposes safety labels', (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SimulationOpsPage())));
    expect(find.text('SIMULATION OPERATIONS'), findsOneWidget);
    expect(find.textContaining('No physical drone connection'), findsOneWidget);
    final start = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'START SIMULATION'));
    expect(start.onPressed, isNull);
  });
}
