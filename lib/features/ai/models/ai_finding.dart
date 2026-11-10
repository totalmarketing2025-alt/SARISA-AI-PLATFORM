import 'dart:convert';

enum DetectionCategory { person, vehicle, object, hazard }
enum ReviewStatus { pending, verified, dismissed }

class AiFinding {
  final String id;
  final String source;
  final DetectionCategory category;
  final double confidence;
  final DateTime timestamp;
  final ReviewStatus status;
  final String notes;
  final String missionId;
  final bool simulated;

  const AiFinding({required this.id, required this.source,
    required this.category, required this.confidence, required this.timestamp,
    this.status = ReviewStatus.pending, this.notes = '',
    this.missionId = '', this.simulated = false});

  AiFinding copyWith({ReviewStatus? status, String? notes, String? missionId}) =>
    AiFinding(id: id, source: source, category: category,
      confidence: confidence, timestamp: timestamp,
      status: status ?? this.status, notes: notes ?? this.notes,
      missionId: missionId ?? this.missionId, simulated: simulated);

  Map<String, dynamic> toJson() => {
    'id': id, 'source': source, 'category': category.name,
    'confidence': confidence, 'timestamp': timestamp.toIso8601String(),
    'status': status.name, 'notes': notes, 'missionId': missionId,
    'simulated': simulated,
  };

  factory AiFinding.fromJson(Map<String, dynamic> json) => AiFinding(
    id: json['id'] as String,
    source: json['source'] as String,
    category: DetectionCategory.values.byName(json['category'] as String),
    confidence: (json['confidence'] as num).toDouble(),
    timestamp: DateTime.parse(json['timestamp'] as String),
    status: ReviewStatus.values.byName(json['status'] as String? ?? 'pending'),
    notes: json['notes'] as String? ?? '',
    missionId: json['missionId'] as String? ?? '',
    simulated: json['simulated'] as bool? ?? false,
  );

  static String encodeAll(List<AiFinding> findings) =>
    jsonEncode(findings.map((finding) => finding.toJson()).toList());

  static List<AiFinding> decodeAll(String raw) =>
    (jsonDecode(raw) as List<dynamic>).map((entry) =>
      AiFinding.fromJson(Map<String, dynamic>.from(entry as Map))).toList();
}

class AiAnalysisSettings {
  final double threshold;
  final Set<DetectionCategory> enabled;
  final String mode;
  const AiAnalysisSettings({this.threshold = 0.75,
    this.enabled = const {DetectionCategory.person, DetectionCategory.vehicle,
      DetectionCategory.object, DetectionCategory.hazard},
    this.mode = 'balanced'});

  bool accepts(AiFinding finding) =>
    enabled.contains(finding.category) && finding.confidence >= threshold;
}
