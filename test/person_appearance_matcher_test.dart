import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sarisa/features/ai/models/ai_finding.dart';
import 'package:sarisa/features/ai/services/native_ai_engine.dart';
import 'package:sarisa/features/ai/services/person_appearance_matcher.dart';

void main() {
  test('same person crop receives full clothing-color similarity', () {
    final image = img.Image(width: 32, height: 64);
    img.fill(image, color: const img.ColorRgb8(30, 80, 180));
    final person = const NativeDetection(category: DetectionCategory.person,
      confidence: 0.95, x: 0, y: 0, width: 1, height: 1);
    final descriptor = PersonAppearanceMatcher.describe(image, person);

    expect(PersonAppearanceMatcher.similarity(descriptor, descriptor), 1);
  });

  test('separate color patterns are ranked below matching appearance', () {
    final blue = img.Image(width: 32, height: 64);
    final red = img.Image(width: 32, height: 64);
    img.fill(blue, color: const img.ColorRgb8(20, 40, 220));
    img.fill(red, color: const img.ColorRgb8(220, 30, 20));
    const box = NativeDetection(category: DetectionCategory.person,
      confidence: 0.9, x: 0, y: 0, width: 1, height: 1);
    final first = PersonAppearanceMatcher.describe(blue, box);
    final second = PersonAppearanceMatcher.describe(red, box);

    expect(PersonAppearanceMatcher.similarity(first, second), lessThan(0.8));
  });

  test('rejects non-person boxes', () {
    final image = img.Image(width: 8, height: 8);
    const vehicle = NativeDetection(category: DetectionCategory.vehicle,
      confidence: 0.9, x: 0, y: 0, width: 1, height: 1);
    expect(() => PersonAppearanceMatcher.describe(image, vehicle),
        throwsFormatException);
  });
}
