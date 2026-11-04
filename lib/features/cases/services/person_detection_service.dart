import 'package:object_detection/object_detection.dart';

class PersonDetectionService {
  PersonDetectionService._();

  static final PersonDetectionService instance =
      PersonDetectionService._();

  ObjectDetector? _detector;
  Future<void>? _initialization;

  Future<void> _ensureInitialized() async {
    if (_detector?.isReady == true) return;

    _initialization ??= _initializeDetector();

    try {
      await _initialization;
    } catch (_) {
      _initialization = null;
      rethrow;
    }
  }

  Future<void> _initializeDetector() async {
    final detector = await ObjectDetector.create(
      model: ObjectDetectionModel.efficientDetLite0,
    );

    _detector = detector;
  }

  Future<List<DetectedObject>> detectPeople(String imagePath) async {
    await _ensureInitialized();

    final detector = _detector;
    if (detector == null || !detector.isReady) {
      throw StateError('Person detector is not ready.');
    }

    return detector.detectFromFilepath(
      imagePath,
      options: const ObjectDetectorOptions(
        scoreThreshold: 0.40,
        maxResults: 20,
        categoryAllowlist: ['person'],
      ),
    );
  }

  Future<void> dispose() async {
    final detector = _detector;
    _detector = null;
    _initialization = null;

    if (detector != null) {
      await detector.dispose();
    }
  }
}
