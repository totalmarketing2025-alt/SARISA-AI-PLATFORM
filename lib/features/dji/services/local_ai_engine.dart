import 'dart:async';

import '../../cases/services/person_detection_service.dart';
import '../models/detection_event.dart';
import '../models/drone_video_source.dart';

typedef PersonFrameAnalyzer = Future<PersonFrameAnalysis> Function(
  String imagePath,
);

class PersonFrameAnalysis {
  final int personCount;
  final double maxConfidence;

  const PersonFrameAnalysis({
    required this.personCount,
    required this.maxConfidence,
  });
}

class LocalAiEngine {
  LocalAiEngine._({
    required PersonFrameAnalyzer analyzer,
    this.maxQueuedFrames = 8,
  }) : _analyzer = analyzer;

  static final LocalAiEngine instance = LocalAiEngine._(
    analyzer: _analyzeWithOnDeviceModel,
  );

  factory LocalAiEngine.forTesting({
    required PersonFrameAnalyzer analyzer,
    int maxQueuedFrames = 8,
  }) {
    if (maxQueuedFrames < 1) {
      throw ArgumentError.value(maxQueuedFrames, 'maxQueuedFrames');
    }

    return LocalAiEngine._(
      analyzer: analyzer,
      maxQueuedFrames: maxQueuedFrames,
    );
  }

  final PersonFrameAnalyzer _analyzer;
  final int maxQueuedFrames;
  final List<_FrameJob> _queue = [];

  bool _processing = false;

  bool get isProcessing => _processing;
  int get queuedFrames => _queue.length;

  static Future<PersonFrameAnalysis> _analyzeWithOnDeviceModel(
    String imagePath,
  ) async {
    final detections =
        await PersonDetectionService.instance.detectPeople(imagePath);

    var maxConfidence = 0.0;

    for (final detection in detections) {
      if (detection.score > maxConfidence) {
        maxConfidence = detection.score;
      }
    }

    return PersonFrameAnalysis(
      personCount: detections.length,
      maxConfidence: maxConfidence,
    );
  }

  Future<DetectionEvent> submitFrame({
    required DroneVideoSource source,
    required String imagePath,
    DateTime? capturedAt,
    double? latitude,
    double? longitude,
  }) {
    if (!source.enabled) {
      return Future.error(StateError('This drone source is disabled.'));
    }

    if (_queue.length >= maxQueuedFrames) {
      return Future.error(StateError('Local AI frame queue is full.'));
    }

    final job = _FrameJob(
      source: source,
      imagePath: imagePath,
      capturedAt: capturedAt ?? DateTime.now(),
      latitude: latitude,
      longitude: longitude,
    );

    _queue.add(job);
    _startQueue();

    return job.completer.future;
  }

  void _startQueue() {
    if (_processing) return;

    _processing = true;
    unawaited(_processQueue());
  }

  Future<void> _processQueue() async {
    try {
      while (_queue.isNotEmpty) {
        final job = _queue.removeAt(0);

        try {
          final result = await _analyzer(job.imagePath);

          job.completer.complete(
            DetectionEvent(
              id: '${job.source.id}_${job.capturedAt.microsecondsSinceEpoch}',
              droneId: job.source.id,
              droneName: job.source.displayName,
              imagePath: job.imagePath,
              capturedAt: job.capturedAt,
              personCount: result.personCount,
              maxConfidence: result.maxConfidence,
              latitude: job.latitude,
              longitude: job.longitude,
            ),
          );
        } catch (error, stackTrace) {
          job.completer.completeError(error, stackTrace);
        }
      }
    } finally {
      _processing = false;

      if (_queue.isNotEmpty) {
        _startQueue();
      }
    }
  }
}

class _FrameJob {
  final DroneVideoSource source;
  final String imagePath;
  final DateTime capturedAt;
  final double? latitude;
  final double? longitude;
  final Completer<DetectionEvent> completer = Completer<DetectionEvent>();

  _FrameJob({
    required this.source,
    required this.imagePath,
    required this.capturedAt,
    this.latitude,
    this.longitude,
  });
}
