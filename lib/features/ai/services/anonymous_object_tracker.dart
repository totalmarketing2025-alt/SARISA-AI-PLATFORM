import '../models/ai_finding.dart';
import 'native_ai_engine.dart';

/// Short-lived, frame-to-frame association for non-person detections only.
/// IDs are in-memory mission labels and are not persisted as identity records.
class AnonymousObjectTracker {
  AnonymousObjectTracker({this.iouThreshold = 0.25, this.maxMissedFrames = 2}) {
    if (!iouThreshold.isFinite || iouThreshold <= 0 || iouThreshold > 1 ||
        maxMissedFrames < 0 || maxMissedFrames > 30) {
      throw ArgumentError('Invalid tracker settings.');
    }
  }

  final double iouThreshold;
  final int maxMissedFrames;
  final Map<int, _Track> _tracks = {};
  int _nextId = 1;
  int _frame = 0;

  List<TrackedDetection> update(List<NativeDetection> detections) {
    _frame++;
    final candidates = <({int trackId, int detectionIndex, double overlap})>[];
    for (final entry in _tracks.entries) {
      for (var i = 0; i < detections.length; i++) {
        final detection = detections[i];
        if (!_trackable(detection) || entry.value.category != detection.category) continue;
        final overlap = _iou(entry.value.detection, detection);
        if (overlap >= iouThreshold) {
          candidates.add((trackId: entry.key, detectionIndex: i, overlap: overlap));
        }
      }
    }
    candidates.sort((a, b) => b.overlap.compareTo(a.overlap));
    final usedTracks = <int>{};
    final usedDetections = <int>{};
    final assignments = <int, int>{};
    for (final pair in candidates) {
      if (usedTracks.contains(pair.trackId) || usedDetections.contains(pair.detectionIndex)) continue;
      usedTracks.add(pair.trackId);
      usedDetections.add(pair.detectionIndex);
      assignments[pair.detectionIndex] = pair.trackId;
    }

    final output = <TrackedDetection>[];
    final updated = <int, _Track>{};
    for (var i = 0; i < detections.length; i++) {
      final detection = detections[i];
      if (!_trackable(detection)) continue;
      final id = assignments[i] ?? _nextId++;
      updated[id] = _Track(detection.category, detection, _frame);
      output.add(TrackedDetection(id, detection));
    }
    for (final entry in _tracks.entries) {
      if (!updated.containsKey(entry.key) && _frame - entry.value.lastFrame <= maxMissedFrames) {
        updated[entry.key] = entry.value;
      }
    }
    _tracks
      ..clear()
      ..addAll(updated);
    return output;
  }

  /// End a mission/video clip and discard all temporary track IDs.
  void reset() {
    _tracks.clear();
    _nextId = 1;
    _frame = 0;
  }

  static bool _trackable(NativeDetection detection) => detection.valid &&
      detection.category != DetectionCategory.person;

  static double _iou(NativeDetection a, NativeDetection b) {
    final left = a.x > b.x ? a.x : b.x;
    final top = a.y > b.y ? a.y : b.y;
    final right = a.x + a.width < b.x + b.width ? a.x + a.width : b.x + b.width;
    final bottom = a.y + a.height < b.y + b.height ? a.y + a.height : b.y + b.height;
    final intersection = (right - left).clamp(0.0, 1.0) * (bottom - top).clamp(0.0, 1.0);
    final union = a.width * a.height + b.width * b.height - intersection;
    return union <= 0 ? 0 : intersection / union;
  }
}

class TrackedDetection {
  const TrackedDetection(this.trackId, this.detection);
  final int trackId;
  final NativeDetection detection;
}

class _Track {
  const _Track(this.category, this.detection, this.lastFrame);
  final DetectionCategory category;
  final NativeDetection detection;
  final int lastFrame;
}
