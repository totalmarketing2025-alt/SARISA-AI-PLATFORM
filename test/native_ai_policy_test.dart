import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sarisa/features/ai/models/ai_finding.dart';
import 'package:sarisa/features/ai/services/native_ai_engine.dart';
import 'package:sarisa/features/ai/services/native_ai_policy.dart';

class FakeEngine implements NativeAiEngine {
  @override
  Future<NativeAiStatus> initialize() async =>
      const NativeAiStatus(true, 'Test fixture');
  @override
  Future<List<NativeDetection>> detectJpeg(Uint8List jpeg) async => const [
    NativeDetection(category: DetectionCategory.person,
      confidence: 0.92, x: 0.1, y: 0.2, width: 0.2, height: 0.3),
    NativeDetection(category: DetectionCategory.vehicle,
      confidence: 0.55, x: 0.3, y: 0.2, width: 0.2, height: 0.3),
    NativeDetection(category: DetectionCategory.person,
      confidence: 0.99, x: 0.9, y: 0.9, width: 0.5, height: 0.5),
  ];
  @override
  Future<void> dispose() async {}
}

void main() {
  test('offline filter rejects weak and invalid detections', () async {
    final findings = await NativeAiPolicy.analyze(
      engine: FakeEngine(), jpeg: Uint8List.fromList([1, 2, 3]),
      settings: const AiAnalysisSettings(threshold: 0.75),
      source: 'authorized camera',
      timestamp: DateTime.utc(2026, 11, 10),
    );
    expect(findings.length, 1);
    expect(findings.single.category, DetectionCategory.person);
    expect(findings.single.simulated, false);
    expect(findings.single.status, ReviewStatus.pending);
  });

  test('missing native model fails closed', () async {
    const engine = UnavailableNativeAiEngine();
    expect((await engine.initialize()).ready, false);
    await expectLater(engine.detectJpeg(Uint8List(0)), throwsStateError);
  });
}
