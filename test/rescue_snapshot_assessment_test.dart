import 'package:flutter_test/flutter_test.dart';
import 'package:sarisa/features/ai/models/ai_finding.dart';
import 'package:sarisa/features/ai/services/native_ai_engine.dart';
import 'package:sarisa/features/ai/services/rescue_snapshot_assessment.dart';

NativeDetection person(double x, double width, double height, {double confidence = 0.9}) =>
    NativeDetection(category: DetectionCategory.person, confidence: confidence,
      x: x, y: 0.1, width: width, height: height);

void main() {
  test('counts people per snapshot and flags only a possible horizontal posture cue', () {
    final assessment = RescueSnapshotAssessment.fromDetections([
      person(0.1, 0.12, 0.4),
      person(0.4, 0.36, 0.2),
      const NativeDetection(category: DetectionCategory.vehicle,
        confidence: 0.99, x: 0.1, y: 0.2, width: 0.5, height: 0.3),
    ]);

    expect(assessment.peopleCount, 2);
    expect(assessment.possibleHorizontalPostureCount, 1);
    expect(assessment.people.first.frameIndex, 1);
    expect(assessment.people[1].frameIndex, 2);
  });

  test('ignores invalid, zero-area and low-confidence person boxes', () {
    final assessment = RescueSnapshotAssessment.fromDetections([
      person(0.1, 0, 0.3),
      person(0.2, 0.2, 0.2, confidence: 0.1),
      person(0.9, 0.3, 0.3),
    ]);
    expect(assessment.peopleCount, 0);
  });

  test('operator assessments keep injury and help as human-confirmed states', () {
    expect(RescueOperatorAssessment.possibleInjury.label,
        contains('operator assessment'));
    expect(RescueOperatorAssessment.requestsHelp.label,
        contains('operator assessment'));
    expect(RescueOperatorAssessment.unreviewed,
        RescueOperatorAssessment.unreviewed);
  });
}
