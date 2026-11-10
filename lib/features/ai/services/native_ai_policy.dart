import 'dart:typed_data';
import '../models/ai_finding.dart';
import 'native_ai_engine.dart';

/// Offline-only filtering and operator-review event conversion.
class NativeAiPolicy {
  static List<NativeDetection> accepted(
    Iterable<NativeDetection> input, AiAnalysisSettings settings,
  ) => input.where((d) => d.valid &&
      settings.enabled.contains(d.category) &&
      d.confidence >= settings.threshold).take(100).toList();

  static Future<List<AiFinding>> analyze({
    required NativeAiEngine engine,
    required Uint8List jpeg,
    required AiAnalysisSettings settings,
    required String source,
    required DateTime timestamp,
  }) async {
    final detections = accepted(await engine.detectJpeg(jpeg), settings);
    return [
      for (var i = 0; i < detections.length; i++)
        AiFinding(
          id: '${timestamp.microsecondsSinceEpoch}-$i',
          source: source,
          category: detections[i].category,
          confidence: detections[i].confidence,
          timestamp: timestamp,
        ),
    ];
  }
}
