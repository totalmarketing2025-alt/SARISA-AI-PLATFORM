import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Non-identifying vehicle appearance matching, not plate/owner identification.
/// Embeddings must be produced by a separately validated local model.
class VehicleVisualCandidate {
  final String localFrameId;
  final List<double> embedding;
  const VehicleVisualCandidate(this.localFrameId, this.embedding);
}

class VehicleVisualSearch {
  /// Produces a small colour-and-layout descriptor from a local vehicle crop.
  /// It is an appearance heuristic for candidate ranking, not a vehicle ID.
  static List<double> describeJpeg(Uint8List jpeg, {
    double x = 0,
    double y = 0,
    double width = 1,
    double height = 1,
  }) {
    if ([x, y, width, height].any((v) => !v.isFinite) ||
        x < 0 || y < 0 || width <= 0 || height <= 0 ||
        x + width > 1.001 || y + height > 1.001) {
      throw const FormatException('Invalid normalized crop.');
    }
    final source = img.decodeImage(jpeg);
    if (source == null || source.width * source.height > 16000000) {
      throw const FormatException('Invalid or oversized image.');
    }
    final left = (x * source.width).floor().clamp(0, source.width - 1).toInt();
    final top = (y * source.height).floor().clamp(0, source.height - 1).toInt();
    final right = ((x + width) * source.width).ceil()
        .clamp(left + 1, source.width).toInt();
    final bottom = ((y + height) * source.height).ceil()
        .clamp(top + 1, source.height).toInt();
    final crop = img.copyCrop(source, x: left, y: top,
        width: right - left, height: bottom - top);
    final sample = img.copyResize(crop, width: 12, height: 8,
        interpolation: img.Interpolation.average);

    // 8-bin RGB histograms and a 4x4 coarse color layout.
    final descriptor = List<double>.filled(24 + 48, 0);
    for (var py = 0; py < sample.height; py++) {
      for (var px = 0; px < sample.width; px++) {
        final pixel = sample.getPixel(px, py);
        final channels = [pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt()];
        for (var channel = 0; channel < 3; channel++) {
          final value = channels[channel].clamp(0, 255).toInt();
          descriptor[channel * 8 + value * 8 ~/ 256] += 1;
          final cellX = px * 4 ~/ sample.width;
          final cellY = py * 4 ~/ sample.height;
          final cell = cellY * 4 + cellX;
          descriptor[24 + channel * 16 + cell] += value / 255;
        }
      }
    }
    for (var channel = 0; channel < 3; channel++) {
      final total = descriptor.sublist(channel * 8, channel * 8 + 8)
          .fold<double>(0, (sum, value) => sum + value);
      if (total > 0) {
        for (var bin = 0; bin < 8; bin++) {
          descriptor[channel * 8 + bin] /= total;
        }
      }
    }
    return _unitNormalize(descriptor);
  }

  static List<double> _unitNormalize(List<double> vector) {
    final norm = math.sqrt(vector.fold<double>(0, (sum, value) => sum + value * value));
    if (norm == 0) throw const FormatException('Empty image descriptor.');
    return vector.map((value) => value / norm).toList(growable: false);
  }

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
