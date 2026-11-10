import 'dart:math' as math;

/// Non-identifying vehicle appearance matching, not plate/owner identification.
/// Embeddings must be produced by a separately validated local model.
class VehicleVisualCandidate {
  final String localFrameId;
  final List<double> embedding;
  const VehicleVisualCandidate(this.localFrameId, this.embedding);
}

class VehicleVisualSearch {
  static double cosineSimilarity(List<double> a, List<double> b) {
    if (a.isEmpty || a.length != b.length ||
        !a.every((v) => v.isFinite) || !b.every((v) => v.isFinite)) {
      throw const FormatException('Invalid vehicle embeddings');
    }
    var dot = 0.0;
    var normA = 0.0;
    var normB = 0.0;
    for (var i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    if (normA <= 0 || normB <= 0) {
      throw const FormatException('Zero-length embedding vector');
    }
    return (dot / (math.sqrt(normA) * math.sqrt(normB))).clamp(-1.0, 1.0).toDouble();
  }

  static List<({String frameId, double score})> rank(
    List<double> query, Iterable<VehicleVisualCandidate> candidates, {
    int limit = 10,
  }) {
    if (limit < 1 || limit > 100) throw const FormatException('Invalid result limit');
    final scored = candidates.map((candidate) => (
      frameId: candidate.localFrameId,
      score: cosineSimilarity(query, candidate.embedding),
    )).toList()..sort((a, b) => b.score.compareTo(a.score));
    return scored.take(limit).toList();
  }
}
