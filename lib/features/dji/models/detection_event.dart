class DetectionEvent {
  final String id;
  final String droneId;
  final String droneName;
  final String imagePath;
  final DateTime capturedAt;
  final int personCount;
  final double maxConfidence;
  final double? latitude;
  final double? longitude;

  const DetectionEvent({
    required this.id,
    required this.droneId,
    required this.droneName,
    required this.imagePath,
    required this.capturedAt,
    required this.personCount,
    required this.maxConfidence,
    this.latitude,
    this.longitude,
  });

  bool get containsPerson => personCount > 0;

  int get maxConfidencePercent => (maxConfidence * 100).round();
}
