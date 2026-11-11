import 'dart:ui' show Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:sarisa/main.dart';

void main() {
  testWidgets('SARISA app starts', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const SarisaApp());

    expect(find.text('SARISA'), findsWidgets);
    expect(find.text('COMMAND CENTER'), findsWidgets);
    expect(tester.takeException(), isNull,
        reason: 'SARISA startup must not throw framework exceptions');
  });
}
