import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:sarisa/features/ai/models/ai_finding.dart';
import 'package:sarisa/features/ai/services/yolox_onnx_engine.dart';

void main() {
  test('YOLOX raw decoder returns person, truck and animal boxes', () {
    final raw = List<double>.filled(84 * 85, 0);
    final rows = [
      (anchor: 0, x: 3.5, classId: 0, score: 0.95),
      (anchor: 1, x: 2.5, classId: 7, score: 0.90),
      (anchor: 2, x: 1.5, classId: 16, score: 0.85),
    ];
    for (final row in rows) {
      final offset = row.anchor * 85;
      raw[offset] = row.x;
      raw[offset + 1] = 3.5;
      raw[offset + 2] = math.log(2);
      raw[offset + 3] = math.log(2);
      raw[offset + 4] = 1;
      raw[offset + 5 + row.classId] = row.score;
    }

    final detections = YoloxOnnxEngine.decodeRawOutput(
      raw,
      sourceWidth: 64,
      sourceHeight: 64,
      confidenceThreshold: 0.5,
      scale: 1,
      modelWidth: 64,
      modelHeight: 64,
    );

    expect(detections.map((item) => item.label), ['person', 'truck', 'dog']);
    expect(detections.map((item) => item.category), [
      DetectionCategory.person,
      DetectionCategory.vehicle,
      DetectionCategory.animal,
    ]);
    for (final detection in detections) {
      expect(detection.valid, isTrue);
      expect(detection.x, closeTo(0.3125, 1e-6));
      expect(detection.y, closeTo(0.3125, 1e-6));
      expect(detection.width, closeTo(0.25, 1e-6));
      expect(detection.height, closeTo(0.25, 1e-6));
    }
  });

  test('YOLOX decoder rejects incompatible anchor counts', () {
    expect(
      () => YoloxOnnxEngine.decodeRawOutput(
        List<double>.filled(83 * 85, 0),
        sourceWidth: 64,
        sourceHeight: 64,
        confidenceThreshold: 0.5,
        scale: 1,
        modelWidth: 64,
        modelHeight: 64,
      ),
      throwsFormatException,
    );
  });
}
