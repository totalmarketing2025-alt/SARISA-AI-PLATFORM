import 'package:flutter_test/flutter_test.dart';
import 'package:sarisa/features/ai/models/ai_finding.dart';
import 'package:sarisa/features/ai/services/ai_finding_repository.dart';

void main() {
  test('AI finding JSON roundtrip retains review and mission reference', () {
    final finding = AiFinding(
      id: 'event-1', source: 'SIM CAM',
      category: DetectionCategory.vehicle, confidence: 0.91,
      timestamp: DateTime.utc(2026, 11, 10), simulated: true);
    final verified = finding.copyWith(
      status: ReviewStatus.verified, missionId: 'mission-1', notes: 'Reviewed');
    final restored = AiFinding.decodeAll(AiFinding.encodeAll([verified])).single;
    expect(restored.status, ReviewStatus.verified);
    expect(restored.missionId, 'mission-1');
    expect(restored.notes, 'Reviewed');
    expect(restored.simulated, isTrue);
  });

  test('simulated detection respects category and confidence filters', () {
    const settings = AiAnalysisSettings(
      threshold: 0.92, enabled: {DetectionCategory.person});
    final findings = SimulatedDetectionEngine.sample('SIM', settings);
    expect(findings, hasLength(1));
    expect(findings.single.category, DetectionCategory.person);
    expect(findings.single.simulated, isTrue);
  });

  test('simulation can be disabled with an empty category set', () {
    const settings = AiAnalysisSettings(enabled: <DetectionCategory>{});
    expect(SimulatedDetectionEngine.sample('SIM', settings), isEmpty);
  });
}
