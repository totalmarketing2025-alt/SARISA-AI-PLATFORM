import 'dart:typed_data';
import '../models/ai_finding.dart';

/// Contract for an on-device inference implementation.
/// No network fallback: missing native runtimes fail closed.
abstract class NativeAiEngine {
  Future<NativeAiStatus> initialize();
  Future<List<NativeDetection>> detectJpeg(Uint8List jpeg);
  Future<void> dispose();
}

class NativeAiStatus {
  final bool ready;
  final String message;
  const NativeAiStatus(this.ready, this.message);
}

class NativeDetection {
  final DetectionCategory category;
  final double confidence;
  final double x;
  final double y;
  final double width;
  final double height;

  const NativeDetection({
    required this.category,
    required this.confidence,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  bool get valid => confidence.isFinite && confidence >= 0 &&
      confidence <= 1 && [x, y, width, height].every(
        (v) => v.isFinite && v >= 0 && v <= 1) &&
      x + width <= 1.001 && y + height <= 1.001;
}

/// Explicitly unavailable until a licensed ONNX model and native platform
/// libraries have been packaged and verified on both target platforms.
class UnavailableNativeAiEngine implements NativeAiEngine {
  const UnavailableNativeAiEngine();

  @override
  Future<NativeAiStatus> initialize() async => const NativeAiStatus(
    false, 'On-device model/runtime not installed. No detections are generated.');

  @override
  Future<List<NativeDetection>> detectJpeg(Uint8List jpeg) async =>
      throw StateError('Native inference is unavailable; no simulated results.');

  @override
  Future<void> dispose() async {}
}
