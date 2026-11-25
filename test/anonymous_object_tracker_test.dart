import 'package:flutter_test/flutter_test.dart';
import 'package:sarisa/features/ai/models/ai_finding.dart';
import 'package:sarisa/features/ai/services/anonymous_object_tracker.dart';
import 'package:sarisa/features/ai/services/native_ai_engine.dart';

NativeDetection detection(DetectionCategory category, double x) => NativeDetection(
  category: category, label: category.name, confidence: 0.9,
  x: x, y: 0.2, width: 0.2, height: 0.2,
);

void main() {
  test('associates a vehicle across nearby frames and never tracks people', () {
    final tracker = AnonymousObjectTracker();
    final first = tracker.update([
      detection(DetectionCategory.person, 0.1),
      detection(DetectionCategory.vehicle, 0.3),
    ]);
    final second = tracker.update([
      detection(DetectionCategory.person, 0.12),
      detection(DetectionCategory.vehicle, 0.32),
    ]);

    expect(first, hasLength(1));
    expect(second, hasLength(1));
    expect(first.single.trackId, second.single.trackId);
    expect(first.single.detection.category, DetectionCategory.vehicle);
  });

  test('allocates new short-lived track IDs after reset or missed-frame expiry', () {
    final tracker = AnonymousObjectTracker(maxMissedFrames: 0);
    final first = tracker.update([detection(DetectionCategory.vehicle, 0.2)]).single;
    tracker.update(const []);
    final afterGap = tracker.update([detection(DetectionCategory.vehicle, 0.2)]).single;
    expect(afterGap.trackId, isNot(first.trackId));
    tracker.reset();
    expect(tracker.update([detection(DetectionCategory.vehicle, 0.2)])
      .single.trackId, 1);
  });
}
