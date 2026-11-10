import 'package:flutter_test/flutter_test.dart';
import 'package:sarisa/features/ai/services/native_ai_manifest.dart';
import 'package:sarisa/features/ai/services/vehicle_visual_search.dart';
import 'package:sarisa/features/ai/services/plate_ocr_validation.dart';

void main() {
  test('no unapproved model is bundled', () {
    expect(approvedNativeModels, isEmpty);
    const model = NativeModelArtifact(role: NativeModelRole.objectDetection,
      filename: 'model.onnx', sha256: 'invalid', licenseId: 'review',
      version: '1');
    expect(model.hasValidDigest, false);
  });

  test('vehicle matching ranks by cosine similarity', () {
    final results = VehicleVisualSearch.rank([1, 0], [
      const VehicleVisualCandidate('different', [0, 1]),
      const VehicleVisualCandidate('similar', [0.9, 0.1]),
    ]);
    expect(results.first.frameId, 'similar');
    expect(results.first.score, greaterThan(0.9));
  });

  test('OCR results require operator review when uncertain', () {
    expect(PlateOcrValidation.parse('SK-1234-AB', 0.70).requiresReview, true);
    expect(PlateOcrValidation.parse('SK-1234-AB', 0.99).normalized, 'SK1234AB');
    expect(() => PlateOcrValidation.parse('ABC', 1.5), throwsFormatException);
  });
}
