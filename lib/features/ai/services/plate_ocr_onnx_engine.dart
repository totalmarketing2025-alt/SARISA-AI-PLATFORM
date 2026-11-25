import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:image/image.dart' as img;

import '../models/ai_finding.dart';
import 'native_ai_engine.dart';
import 'plate_ocr_validation.dart';

/// PP-OCRv5 Latin OCR running locally on vehicle crops. This reads visible
/// text only; every plate-shaped result remains a suggestion for an operator.
class PlateOcrOnnxEngine {
  static const detectorAsset = 'assets/models/ocr_det.onnx';
  static const recognizerAsset = 'assets/models/ocr_rec_latin.onnx';
  static const dictionaryAsset = 'assets/models/ppocrv5_latin_dict.txt';
  static const _dictionarySize = 838;

  final OnnxRuntime _runtime = OnnxRuntime();
  OrtSession? _detector;
  OrtSession? _recognizer;
  List<String> _dictionary = const [];

  Future<NativeAiStatus> initialize() async {
    try {
      _detector ??= await _runtime.createSessionFromAsset(detectorAsset,
        options: OrtSessionOptions(providers: [OrtProvider.CPU],
          intraOpNumThreads: 2, interOpNumThreads: 1));
      _recognizer ??= await _runtime.createSessionFromAsset(recognizerAsset,
        options: OrtSessionOptions(providers: [OrtProvider.CPU],
          intraOpNumThreads: 2, interOpNumThreads: 1));
      final dictionary = (await rootBundle.loadString(dictionaryAsset))
          .split('\n').map((line) => line.replaceAll('\r', '')).toList();
      while (dictionary.isNotEmpty && dictionary.last.isEmpty) { dictionary.removeLast(); }
      // PP-OCR adds a trailing space token after the 836 dictionary entries;
      // index 0 in the model output is the CTC blank.
      if (dictionary.length == _dictionarySize - 2) dictionary.add(' ');
      if (dictionary.length != _dictionarySize - 1) {
        throw const FormatException('OCR dictionary is incomplete.');
      }
      _dictionary = dictionary;
      return const NativeAiStatus(true, 'PP-OCRv5 ready • offline CPU • Latin text');
    } catch (error) {
      return NativeAiStatus(false, 'Could not load local OCR models: $error');
    }
  }

  /// Reads plate-shaped text from each detector-confirmed vehicle crop.
  /// Results are in-memory suggestions and must be checked by the operator.
  Future<List<PlateOcrCandidate>> readVehicleText(
    Uint8List jpeg, List<NativeDetection> detections,
  ) async {
    if (_detector == null || _recognizer == null || _dictionary.isEmpty) {
      throw StateError('Initialize PP-OCR before reading local images.');
    }
    final source = img.decodeImage(jpeg);
    if (source == null || source.width * source.height > 16000000) {
      throw const FormatException('Invalid or oversized image for OCR.');
    }
    final candidates = <PlateOcrCandidate>[];
    for (final detection in detections) {
      if (detection.category != DetectionCategory.vehicle || !detection.valid) continue;
      final x = (detection.x * source.width).floor().clamp(0, source.width - 1).toInt();
      final y = (detection.y * source.height).floor().clamp(0, source.height - 1).toInt();
      final right = ((detection.x + detection.width) * source.width).ceil()
          .clamp(x + 1, source.width).toInt();
      final bottom = ((detection.y + detection.height) * source.height).ceil()
          .clamp(y + 1, source.height).toInt();
      final crop = img.copyCrop(source, x: x, y: y,
          width: right - x, height: bottom - y);
      for (final line in await _detectTextLines(crop)) {
        final reading = await _recognize(crop, line);
        if (reading == null || !looksLikePlateText(reading.text)) continue;
        candidates.add(PlateOcrValidation.parse(reading.text, reading.confidence));
      }
    }
    return candidates;
  }

  Future<List<_TextBox>> _detectTextLines(img.Image source) async {
    final session = _detector!;
    final resized = _resizeDetectorImage(source);
    final image = resized.image;
    final input = _bgrTensor(image, normalize: true);
    final tensor = await OrtValue.fromList(input, [1, 3, image.height, image.width]);
    Map<String, OrtValue>? outputs;
    try {
      outputs = await session.run({session.inputNames.first: tensor});
      final output = outputs[session.outputNames.first];
      if (output == null) throw StateError('Text detector returned no output.');
      final values = (await output.asFlattenedList())
          .map((value) => (value as num).toDouble()).toList(growable: false);
      // PP-OCRv5 mobile detector exports a full-resolution probability map.
      final mapWidth = image.width;
      final mapHeight = image.height;
      if (values.length != mapWidth * mapHeight) {
        throw const FormatException('Unsupported PP-OCR text detector output.');
      }
      final boxes = _components(values, mapWidth, mapHeight)
          .map((box) => _TextBox(
            x: (box.left / mapWidth * source.width).floor().clamp(0, source.width - 1).toInt(),
            y: (box.top / mapHeight * source.height).floor().clamp(0, source.height - 1).toInt(),
            width: ((box.right - box.left) / mapWidth * source.width).ceil()
                .clamp(1, source.width).toInt(),
            height: ((box.bottom - box.top) / mapHeight * source.height).ceil()
                .clamp(1, source.height).toInt(),
          )).toList();
      return boxes.where((box) => box.width >= 12 && box.height >= 6).take(30).toList();
    } finally {
      await tensor.dispose();
      if (outputs != null) {
        for (final value in outputs.values) { await value.dispose(); }
      }
    }
  }

  Future<({String text, double confidence})?> _recognize(
      img.Image source, _TextBox box) async {
    final left = box.x.clamp(0, source.width - 1).toInt();
    final top = box.y.clamp(0, source.height - 1).toInt();
    final width = box.width.clamp(1, source.width - left).toInt();
    final height = box.height.clamp(1, source.height - top).toInt();
    final crop = img.copyCrop(source, x: left, y: top, width: width, height: height);
    const inputHeight = 48;
    const inputWidth = 320;
    final resizedWidth = (crop.width * inputHeight / crop.height)
        .round().clamp(1, inputWidth).toInt();
    final resized = img.copyResize(crop, width: resizedWidth, height: inputHeight,
        interpolation: img.Interpolation.linear);
    final tensorData = Float32List(3 * inputHeight * inputWidth);
    const plane = inputHeight * inputWidth;
    for (var row = 0; row < inputHeight; row++) {
      for (var col = 0; col < resizedWidth; col++) {
        final pixel = resized.getPixel(col, row);
        final offset = row * inputWidth + col;
        tensorData[offset] = pixel.b.toDouble() / 127.5 - 1;
        tensorData[plane + offset] = pixel.g.toDouble() / 127.5 - 1;
        tensorData[plane * 2 + offset] = pixel.r.toDouble() / 127.5 - 1;
      }
    }
    final tensor = await OrtValue.fromList(tensorData, [1, 3, inputHeight, inputWidth]);
    Map<String, OrtValue>? outputs;
    try {
      outputs = await _recognizer!.run({_recognizer!.inputNames.first: tensor});
      final output = outputs[_recognizer!.outputNames.first];
      if (output == null) throw StateError('Text recognizer returned no output.');
      final values = (await output.asFlattenedList())
          .map((value) => (value as num).toDouble()).toList(growable: false);
      if (values.isEmpty || values.length % _dictionarySize != 0) {
        throw const FormatException('Unsupported PP-OCR recognizer output.');
      }
      return decodeCtc(values, _dictionary);
    } finally {
      await tensor.dispose();
      if (outputs != null) {
        for (final value in outputs.values) { await value.dispose(); }
      }
    }
  }

  static ({String text, double confidence})? decodeCtc(
      List<double> values, List<String> dictionary) {
    const classes = _dictionarySize;
    if (values.isEmpty || values.length % classes != 0 || dictionary.length < classes - 1) {
      throw const FormatException('Invalid PP-OCR CTC data.');
    }
    final steps = values.length ~/ classes;
    final text = StringBuffer();
    var previous = -1;
    var confidenceTotal = 0.0;
    var characters = 0;
    for (var step = 0; step < steps; step++) {
      final base = step * classes;
      var best = 0;
      var bestValue = double.negativeInfinity;
      var maxLogit = double.negativeInfinity;
      for (var id = 0; id < classes; id++) {
        final value = values[base + id];
        if (!value.isFinite) continue;
        if (value > bestValue) { bestValue = value; best = id; }
        if (value > maxLogit) maxLogit = value;
      }
      if (best > 0 && best != previous) {
        if (best - 1 < dictionary.length) {
          text.write(dictionary[best - 1]);
          var denominator = 0.0;
          for (var id = 0; id < classes; id++) {
            final value = values[base + id];
            if (value.isFinite) denominator += math.exp((value - maxLogit).clamp(-80, 0));
          }
          confidenceTotal += math.exp(bestValue - maxLogit) / denominator;
          characters++;
        }
      }
      previous = best;
    }
    final result = text.toString().trim();
    if (result.isEmpty || characters == 0) return null;
    return (text: result, confidence: confidenceTotal / characters);
  }

  static bool looksLikePlateText(String text) {
    final normalized = text.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    return RegExp(r'^(NMK|MK)?[A-Z]{2}[0-9]{3,4}[A-Z]{2,3}$')
        .hasMatch(normalized);
  }

  static _ResizedImage _resizeDetectorImage(img.Image source) {
    const limit = 640;
    // Upscale vehicle crops as well as shrinking large source frames so small
    // plate text reaches the detector at a useful resolution.
    final scale = limit / math.max(source.width, source.height);
    var width = math.max(32, (source.width * scale).floor()).toInt();
    var height = math.max(32, (source.height * scale).floor()).toInt();
    width = (width + 31) ~/ 32 * 32;
    height = (height + 31) ~/ 32 * 32;
    return _ResizedImage(img.copyResize(source, width: width, height: height,
        interpolation: img.Interpolation.linear));
  }

  static Float32List _bgrTensor(img.Image image, {required bool normalize}) {
    final plane = image.width * image.height;
    final data = Float32List(3 * plane);
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final offset = y * image.width + x;
        final factor = normalize ? 1 / 127.5 : 1;
        final shift = normalize ? 1 : 0;
        data[offset] = (pixel.b * factor - shift).toDouble();
        data[plane + offset] = (pixel.g * factor - shift).toDouble();
        data[2 * plane + offset] = (pixel.r * factor - shift).toDouble();
      }
    }
    return data;
  }

  static List<_MapBox> _components(List<double> map, int width, int height) {
    final seen = Uint8List(width * height);
    final boxes = <_MapBox>[];
    final queue = <int>[];
    for (var start = 0; start < map.length; start++) {
      if (seen[start] != 0 || !map[start].isFinite || map[start] < 0.30) continue;
      seen[start] = 1;
      queue.add(start);
      var minX = start % width;
      var maxX = minX;
      var minY = start ~/ width;
      var maxY = minY;
      var count = 0;
      for (var cursor = 0; cursor < queue.length; cursor++) {
        final item = queue[cursor];
        final x = item % width;
        final y = item ~/ width;
        count++;
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
        for (var dy = -1; dy <= 1; dy++) {
          for (var dx = -1; dx <= 1; dx++) {
            final nx = x + dx;
            final ny = y + dy;
            if (nx < 0 || nx >= width || ny < 0 || ny >= height) continue;
            final next = ny * width + nx;
            if (seen[next] == 0 && map[next].isFinite && map[next] >= 0.30) {
              seen[next] = 1;
              queue.add(next);
            }
          }
        }
      }
      if (count >= 3) boxes.add(_MapBox(minX, minY, maxX + 1, maxY + 1));
      queue.clear();
      if (boxes.length >= 50) break;
    }
    return boxes;
  }

  Future<void> dispose() async {
    await _detector?.close();
    await _recognizer?.close();
    _detector = null;
    _recognizer = null;
    _dictionary = const [];
  }
}

class _MapBox {
  const _MapBox(this.left, this.top, this.right, this.bottom);
  final int left, top, right, bottom;
}
class _TextBox {
  const _TextBox({required this.x, required this.y, required this.width, required this.height});
  final int x, y, width, height;
}
class _ResizedImage {
  const _ResizedImage(this.image);
  final img.Image image;
}
