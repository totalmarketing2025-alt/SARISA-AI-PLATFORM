import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/ai_finding.dart';

/// Local-only finding storage. No camera stream or biometric data is uploaded.
class AiFindingRepository {
  Future<File> _file() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/sarisa_ai_findings.json');
  }

  Future<List<AiFinding>> load() async {
    final file = await _file();
    if (!await file.exists()) return [];
    return AiFinding.decodeAll(await file.readAsString());
  }

  Future<void> save(List<AiFinding> findings) async {
    final file = await _file();
    await file.writeAsString(AiFinding.encodeAll(findings), flush: true);
  }
}

/// A deterministic, explicitly simulated source for operator workflow tests.
/// This is NOT a trained AI model and does not inspect live video frames.
class SimulatedDetectionEngine {
  static List<AiFinding> sample(String source, AiAnalysisSettings settings) {
    final now = DateTime.now().toUtc();
    final templates = <AiFinding>[
      AiFinding(id: '${now.microsecondsSinceEpoch}-person',
        source: source, category: DetectionCategory.person,
        confidence: 0.94, timestamp: now, simulated: true),
      AiFinding(id: '${now.microsecondsSinceEpoch}-vehicle',
        source: source, category: DetectionCategory.vehicle,
        confidence: 0.91, timestamp: now, simulated: true),
      AiFinding(id: '${now.microsecondsSinceEpoch}-hazard',
        source: source, category: DetectionCategory.hazard,
        confidence: 0.68, timestamp: now, simulated: true),
    ];
    return templates.where(settings.accepts).toList();
  }
}
