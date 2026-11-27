import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sarisa/features/ai/models/ai_finding.dart';
import 'package:sarisa/features/ai/services/native_ai_engine.dart';
import 'package:sarisa/features/ai/services/person_appearance_matcher.dart';

void main() {
  test('same person crop receives full clothing-color similarity', () {
    final image = img.Image(width: 32, height: 64);
    img.fill(image, color: img.ColorRgb8(30, 80, 180));
    final person = const NativeDetection(category: DetectionCategory.person,
      confidence: 0.95, x: 0, y: 0, width: 1, height: 1);
    final descriptor = PersonAppearanceMatcher.describe(image, person);

    expect(PersonAppearanceMatcher.similarity(descriptor, descriptor), 1);
  });

  test('separate color patterns are ranked below matching appearance', () {
    final blue = img.Image(width: 32, height: 64);
    final red = img.Image(width: 32, height: 64);
    img.fill(blue, color: img.ColorRgb8(20, 40, 220));
    img.fill(red, color: img.ColorRgb8(220, 30, 20));
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

  test('profile compares against multiple reference views and session samples', () {
    final blue = img.Image(width: 32, height: 64);
    final red = img.Image(width: 32, height: 64);
    img.fill(blue, color: img.ColorRgb8(20, 40, 220));
    img.fill(red, color: img.ColorRgb8(220, 30, 20));
    const person = NativeDetection(category: DetectionCategory.person,
      confidence: 0.9, x: 0, y: 0, width: 1, height: 1);
    final blueView = PersonAppearanceMatcher.describe(blue, person);
    final redView = PersonAppearanceMatcher.describe(red, person);
    final profile = PersonAppearanceProfile()..replace([blueView]);

    expect(profile.similarityTo(redView), lessThan(0.8));
    expect(profile.addConfirmed(redView), AppearanceSampleAddResult.added);
    expect(profile.addConfirmed(redView), AppearanceSampleAddResult.duplicate);
    expect(profile.sampleCount, 2);
    expect(profile.similarityTo(redView), 1);
    expect(profile.similarityTo(blueView), 1);
  });

  test('profile is capped and can be cleared between SAR sessions', () {
    final image = img.Image(width: 16, height: 32);
    img.fill(image, color: img.ColorRgb8(50, 90, 120));
    const person = NativeDetection(category: DetectionCategory.person,
      confidence: 0.9, x: 0, y: 0, width: 1, height: 1);
    final sample = PersonAppearanceMatcher.describe(image, person);
    final profile = PersonAppearanceProfile()
      ..replace(List.generate(PersonAppearanceProfile.maxSamples, (_) => sample));

    expect(profile.addConfirmed(sample), AppearanceSampleAddResult.duplicate);
    final otherImage = img.Image(width: 16, height: 32);
    img.fill(otherImage, color: img.ColorRgb8(210, 15, 180));
    final differentSample = PersonAppearanceMatcher.describe(otherImage, person);
    expect(profile.addConfirmed(differentSample), AppearanceSampleAddResult.full);
    expect(profile.sampleCount, PersonAppearanceProfile.maxSamples);
    profile.clear();
    expect(profile.isEmpty, isTrue);
    expect(profile.similarityTo(sample), isNull);
  });
}
