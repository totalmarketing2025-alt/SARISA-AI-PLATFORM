import 'package:flutter_test/flutter_test.dart';
import 'package:sarisa/main.dart';

void main() {
  testWidgets('SARISA app starts', (tester) async {
    await tester.pumpWidget(const SarisaApp());
    expect(find.text('SARISA'), findsWidgets);
    expect(find.text('Operations overview'), findsOneWidget);
  });
}
