import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sarisa/features/ai/services/native_ai_manifest.dart';
import 'package:sarisa/features/ai/services/vehicle_visual_search.dart';
import 'package:sarisa/features/ai/services/plate_ocr_validation.dart';
import 'package:sarisa/features/ai/services/plate_ocr_onnx_engine.dart';

void main() {
  test('the bundled YOLOX model has pinned license and digest metadata', () {
    expect(approvedNativeModels, hasLength(3));
    expect(approvedNativeModels.map((model) => model.filename), containsAll([
      'yolox_nano.onnx', 'ocr_det.onnx', 'ocr_rec_latin.onnx',
    ]));
    expect(approvedNativeModels.every((model) => model.licenseId == 'Apache-2.0'), true);
    expect(approvedNativeModels.every((model) => model.hasMetadata && model.hasValidDigest), true);
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

  test('vehicle appearance descriptors rank local image crops', () {
    final red = img.Image(width: 32, height: 24)..clear(img.ColorRgb8(220, 30, 30));
    final nearRed = img.Image(width: 32, height: 24)..clear(img.ColorRgb8(200, 40, 35));
    final blue = img.Image(width: 32, height: 24)..clear(img.ColorRgb8(20, 30, 220));
    final query = VehicleVisualSearch.describeJpeg(img.encodeJpg(red));
    final candidates = [
      VehicleVisualCandidate('blue-frame', VehicleVisualSearch.describeJpeg(img.encodeJpg(blue))),
      VehicleVisualCandidate('red-frame', VehicleVisualSearch.describeJpeg(img.encodeJpg(nearRed))),
    ];

    expect(VehicleVisualSearch.rank(query, candidates).first.frameId, 'red-frame');
    expect(() => VehicleVisualSearch.describeJpeg(Uint8List.fromList([1, 2, 3])),
        throwsFormatException);
  });

  test('OCR results require operator review when uncertain', () {
    expect(PlateOcrValidation.parse('SK-1234-AB', 0.70).requiresReview, true);
    expect(PlateOcrValidation.parse('SK-1234-AB', 0.99).operatorReviewRequired, true);
    expect(PlateOcrValidation.parse('SK-1234-AB', 0.99).normalized, 'SK1234AB');
    expect(() => PlateOcrValidation.parse('ABC', 1.5), throwsFormatException);
  });

  test('plate OCR recognizes only plate-shaped Latin candidates', () {
    expect(PlateOcrOnnxEngine.looksLikePlateText('SK-1234-AB'), isTrue);
    expect(PlateOcrOnnxEngine.looksLikePlateText('NMK SK 1234 AB'), isTrue);
    expect(PlateOcrOnnxEngine.looksLikePlateText('SEARCH AND RESCUE'), isFalse);
  });

  test('PP-OCR CTC decoder collapses repeated tokens and omits blank', () {
    final dictionary = List<String>.filled(837, '?');
    dictionary[0] = 'S';
    dictionary[1] = 'K';
    dictionary[2] = '1';
    final values = List<double>.filled(5 * 838, -8);
    void setToken(int step, int token) => values[step * 838 + token] = 8;
    setToken(0, 1); // S
    setToken(1, 1); // repeated S collapses
    setToken(2, 0); // CTC blank
    setToken(3, 2); // K
    setToken(4, 3); // 1

    final decoded = PlateOcrOnnxEngine.decodeCtc(values, dictionary);
    expect(decoded?.text, 'SK1');
    expect(decoded!.confidence, greaterThan(0.99));
  });
}
