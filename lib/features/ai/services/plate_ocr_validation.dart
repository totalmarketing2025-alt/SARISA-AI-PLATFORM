/// OCR result validation only. This module does not identify owners or query
/// external registries. Plate text must not be stored without authorization.
class PlateOcrCandidate {
  final String text;
  final double confidence;
  const PlateOcrCandidate(this.text, this.confidence);

  String get normalized => text.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  bool get requiresReview => !confidence.isFinite ||
      confidence < 0.95 || normalized.length < 4 ||
      normalized.length > 12;
}

class PlateOcrValidation {
  static PlateOcrCandidate parse(String raw, double confidence) {
    if (raw.length > 32 || !confidence.isFinite ||
        confidence < 0 || confidence > 1) {
      throw const FormatException('Invalid OCR result');
    }
    return PlateOcrCandidate(raw, confidence);
  }
}
