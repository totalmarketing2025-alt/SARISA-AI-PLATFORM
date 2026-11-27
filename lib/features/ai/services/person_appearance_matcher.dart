import 'dart:math' as math;

import 'package:image/image.dart' as img;

import '../models/ai_finding.dart';
import 'native_ai_engine.dart';

/// Session-only clothing/color similarity for SAR candidate ranking.
/// This is not face recognition and cannot establish a person's identity.
class PersonAppearanceMatcher {
  static const _bands = 4;
  static const _channels = 3;
  static const _bins = 8;

  static List<double> describe(img.Image image, NativeDetection box) {
    if (!box.valid || box.category != DetectionCategory.person ||
        image.width <= 0 || image.height <= 0) {
      throw const FormatException('A valid person box and image are required.');
    }
    final left = (box.x * image.width).floor().clamp(0, image.width - 1).toInt();
    final top = (box.y * image.height).floor().clamp(0, image.height - 1).toInt();
    final right = ((box.x + box.width) * image.width).ceil()
        .clamp(left + 1, image.width).toInt();
    final bottom = ((box.y + box.height) * image.height).ceil()
        .clamp(top + 1, image.height).toInt();
    final crop = img.copyCrop(image, x: left, y: top,
        width: right - left, height: bottom - top);
    final sample = img.copyResize(crop, width: 16, height: 32,
        interpolation: img.Interpolation.average);
    final vector = List<double>.filled(_bands * _channels * _bins, 0);
    final counts = List<int>.filled(_bands, 0);
    for (var y = 0; y < sample.height; y++) {
      final band = (y * _bands ~/ sample.height).clamp(0, _bands - 1);
      for (var x = 0; x < sample.width; x++) {
        final pixel = sample.getPixel(x, y);
        final values = [pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt()];
        counts[band]++;
        for (var channel = 0; channel < _channels; channel++) {
          final bin = values[channel].clamp(0, 255) * _bins ~/ 256;
          vector[(band * _channels + channel) * _bins + bin]++;
        }
      }
    }
    for (var band = 0; band < _bands; band++) {
      final denominator = counts[band] * _channels;
      for (var index = band * _channels * _bins;
          index < (band + 1) * _channels * _bins; index++) {
        vector[index] /= denominator;
      }
    }
    final norm = math.sqrt(vector.fold<double>(0,
        (sum, value) => sum + value * value));
    if (norm == 0 || !norm.isFinite) {
      throw const FormatException('Could not describe person appearance.');
    }
    return vector.map((value) => value / norm).toList(growable: false);
  }

  static double similarity(List<double> reference, List<double> candidate) {
    if (reference.length != _bands * _channels * _bins ||
        candidate.length != reference.length ||
        !reference.every((value) => value.isFinite) ||
        !candidate.every((value) => value.isFinite)) {
      throw const FormatException('Invalid person appearance descriptor.');
    }
    var dot = 0.0;
    var normA = 0.0;
    var normB = 0.0;
    for (var index = 0; index < reference.length; index++) {
      dot += reference[index] * candidate[index];
      normA += reference[index] * reference[index];
      normB += candidate[index] * candidate[index];
    }
    if (normA == 0 || normB == 0) {
      throw const FormatException('Empty person appearance descriptor.');
    }
    return (dot / (math.sqrt(normA) * math.sqrt(normB)))
        .clamp(0.0, 1.0).toDouble();
  }
}

/// Session-only few-shot profile for operator-provided SAR appearance samples.
/// It does not fine-tune or modify the YOLO model weights.
enum AppearanceSampleAddResult { added, duplicate, full }

class PersonAppearanceProfile {
  static const maxSamples = 8;
  final List<List<double>> _samples = [];

  int get sampleCount => _samples.length;
  bool get isEmpty => _samples.isEmpty;

  void replace(Iterable<List<double>> samples) {
    _samples.clear();
    for (final sample in samples.take(maxSamples)) {
      _addValidated(sample);
    }
  }

  AppearanceSampleAddResult addConfirmed(List<double> sample) {
    for (final existing in _samples) {
      if (PersonAppearanceMatcher.similarity(existing, sample) >= 0.995) {
        return AppearanceSampleAddResult.duplicate;
      }
    }
    if (_samples.length >= maxSamples) return AppearanceSampleAddResult.full;
    _addValidated(sample);
    return AppearanceSampleAddResult.added;
  }

  double? similarityTo(List<double> candidate) {
    if (_samples.isEmpty) return null;
    var best = 0.0;
    for (final sample in _samples) {
      final score = PersonAppearanceMatcher.similarity(sample, candidate);
      if (score > best) best = score;
    }
    return best;
  }

  void clear() => _samples.clear();

  void _addValidated(List<double> sample) {
    // Self-similarity validates length, finite values and nonzero magnitude.
    PersonAppearanceMatcher.similarity(sample, sample);
    _samples.add(List<double>.unmodifiable(sample));
  }
}
