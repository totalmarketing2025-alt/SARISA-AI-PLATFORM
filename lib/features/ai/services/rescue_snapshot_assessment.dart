import '../models/ai_finding.dart';
import 'native_ai_engine.dart';

/// Frame-local, anonymous person observations for SAR triage.
/// This reports visual cues only; it does not diagnose injury or infer intent.
class RescueSnapshotAssessment {
  RescueSnapshotAssessment._(this.people);

  factory RescueSnapshotAssessment.fromDetections(
    Iterable<NativeDetection> detections, {
    double minimumConfidence = 0.25,
    double horizontalPostureRatio = 1.2,
  }) {
    if (!minimumConfidence.isFinite || minimumConfidence < 0 ||
        minimumConfidence > 1 || !horizontalPostureRatio.isFinite ||
        horizontalPostureRatio <= 1) {
      throw ArgumentError('Invalid rescue assessment thresholds.');
    }
    final persons = detections.where((item) => item.valid &&
        item.category == DetectionCategory.person &&
        item.width > 0 && item.height > 0 &&
        item.confidence >= minimumConfidence).toList(growable: false);
    return RescueSnapshotAssessment._([
      for (var i = 0; i < persons.length; i++)
        RescuePersonObservation(
          frameIndex: i + 1,
          confidence: persons[i].confidence,
          x: persons[i].x,
          y: persons[i].y,
          width: persons[i].width,
          height: persons[i].height,
          possibleHorizontalPosture:
              persons[i].width / persons[i].height >= horizontalPostureRatio,
        ),
    ]);
  }

  final List<RescuePersonObservation> people;
  int get peopleCount => people.length;
  int get possibleHorizontalPostureCount =>
      people.where((person) => person.possibleHorizontalPosture).length;
}

class RescuePersonObservation {
  const RescuePersonObservation({
    required this.frameIndex,
    required this.confidence,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.possibleHorizontalPosture,
  });

  /// A temporary index inside this snapshot; it is not a track or identity.
  final int frameIndex;
  final double confidence;
  final double x;
  final double y;
  final double width;
  final double height;
  final bool possibleHorizontalPosture;
}

enum RescueOperatorAssessment {
  unreviewed('Needs visual review'),
  noVisibleProblem('No visible problem observed'),
  possibleInjury('Possible injury — operator assessment'),
  requestsHelp('Appears to request help — operator assessment'),
  otherProblem('Other visible problem — operator assessment'),
  unclear('Unable to assess');

  const RescueOperatorAssessment(this.label);
  final String label;
}
