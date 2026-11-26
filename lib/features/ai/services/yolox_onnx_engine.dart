import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:image/image.dart' as img;

import '../models/ai_finding.dart';
import 'native_ai_engine.dart';

/// Local, CPU-only YOLOX-Nano COCO-80 engine for the Android/Windows app.
/// This detects object classes and does not identify or track people.
class YoloxOnnxEngine implements NativeAiEngine {
  static const modelAsset = 'assets/models/yolox_nano.onnx';
  static const modelSize = 416;
  static const classes = <String>[
    'person', 'bicycle', 'car', 'motorcycle', 'airplane', 'bus', 'train',
    'truck', 'boat', 'traffic light', 'fire hydrant', 'stop sign',
    'parking meter', 'bench', 'bird', 'cat', 'dog', 'horse', 'sheep', 'cow',
    'elephant', 'bear', 'zebra', 'giraffe', 'backpack', 'umbrella', 'handbag',
    'tie', 'suitcase', 'frisbee', 'skis', 'snowboard', 'sports ball', 'kite',
    'baseball bat', 'baseball glove', 'skateboard', 'surfboard', 'tennis racket',
    'bottle', 'wine glass', 'cup', 'fork', 'knife', 'spoon', 'bowl', 'banana',
    'apple', 'sandwich', 'orange', 'broccoli', 'carrot', 'hot dog', 'pizza',
    'donut', 'cake', 'chair', 'couch', 'potted plant', 'bed', 'dining table',
    'toilet', 'tv', 'laptop', 'mouse', 'remote', 'keyboard', 'cell phone',
    'microwave', 'oven', 'toaster', 'sink', 'refrigerator', 'book', 'clock',
    'vase', 'scissors', 'teddy bear', 'hair drier', 'toothbrush',
  ];
  static const _vehicleClasses = {1, 2, 3, 5, 6, 7, 8};
  static const _animalClasses = {14, 15, 16, 17, 18, 19, 20, 21, 22, 23};

  final OnnxRuntime _runtime = OnnxRuntime();
  OrtSession? _session;

  @override
  Future<NativeAiStatus> initialize() async {
    if (!Platform.isAndroid && !Platform.isWindows) {
      return const NativeAiStatus(false, 'YOLOX is supported on Android and Windows only.');
    }
    try {
      _session ??= await _runtime.createSessionFromAsset(
        modelAsset,
        options: OrtSessionOptions(
          providers: [OrtProvider.CPU],
          intraOpNumThreads: 2,
          interOpNumThreads: 1,
        ),
      );
      return const NativeAiStatus(true, 'YOLOX-Nano ready • offline CPU • COCO-80');
    } catch (error) {
      return NativeAiStatus(false, 'Could not load local ONNX model: $error');
    }
  }

  @override
  Future<List<NativeDetection>> detectJpeg(Uint8List jpeg) async {
    final decoded = img.decodeImage(jpeg);
    if (decoded == null) throw const FormatException('Image is not a supported JPEG.');
    return detectImage(decoded);
  }

  /// Runs inference directly on a decoded camera frame, avoiding a JPEG
  /// encode/decode round-trip on every live frame.
  Future<List<NativeDetection>> detectImage(img.Image decoded) async {
    final session = _session;
    if (session == null) throw StateError('Initialize the local ONNX model first.');
    if (decoded.width * decoded.height > 16000000) {
      throw const FormatException('Image exceeds the 16 megapixel safety limit.');
    }
    final scale = _scale(decoded.width, decoded.height, modelSize, modelSize);
    final resizedWidth = (decoded.width * scale).toInt().clamp(1, modelSize).toInt();
    final resizedHeight = (decoded.height * scale).toInt().clamp(1, modelSize).toInt();
    final resized = img.copyResize(
      decoded,
      width: resizedWidth,
      height: resizedHeight,
      interpolation: img.Interpolation.linear,
    );
    final input = Float32List(3 * modelSize * modelSize);
    input.fillRange(0, input.length, 114.0);
    final plane = modelSize * modelSize;
    // Official YOLOX preprocessing uses BGR, 0..255 floats, and top-left padding.
    for (var y = 0; y < resizedHeight; y++) {
      for (var x = 0; x < resizedWidth; x++) {
        final pixel = resized.getPixel(x, y);
        final offset = y * modelSize + x;
        input[offset] = pixel.b.toDouble();
        input[plane + offset] = pixel.g.toDouble();
        input[2 * plane + offset] = pixel.r.toDouble();
      }
    }

    final inputTensor = await OrtValue.fromList(input, [1, 3, modelSize, modelSize]);
    Map<String, OrtValue>? outputs;
    try {
      outputs = await session.run({session.inputNames.first: inputTensor});
      final output = outputs[session.outputNames.first];
      if (output == null) throw StateError('ONNX model returned no detection tensor.');
      final values = (await output.asFlattenedList())
          .map((value) => (value as num).toDouble()).toList(growable: false);
      return decodeRawOutput(
        values,
        sourceWidth: decoded.width,
        sourceHeight: decoded.height,
        confidenceThreshold: 0.25,
        scale: scale,
        modelWidth: modelSize,
        modelHeight: modelSize,
      );
    } finally {
      await inputTensor.dispose();
      if (outputs != null) {
        for (final value in outputs.values) {
          await value.dispose();
        }
      }
    }
  }

  /// Decodes the official raw YOLOX layout [1, anchors, 5 + 80].
  /// Kept pure so CI can exercise real box/class decoding without native binaries.
  static List<NativeDetection> decodeRawOutput(
    List<double> values, {
    required int sourceWidth,
    required int sourceHeight,
    required double confidenceThreshold,
    required double scale,
    required int modelWidth,
    required int modelHeight,
  }) {
    if (values.length % 85 != 0 || scale <= 0 ||
        confidenceThreshold <= 0 || confidenceThreshold > 1) {
      throw const FormatException('Invalid YOLOX output or decode parameters.');
    }
    final strides = [8, 16, 32];
    final grid = <(int, int, int)>[];
    for (final stride in strides) {
      for (var y = 0; y < modelHeight ~/ stride; y++) {
        for (var x = 0; x < modelWidth ~/ stride; x++) {
          grid.add((x, y, stride));
        }
      }
    }
    final anchorCount = values.length ~/ 85;
    if (grid.length != anchorCount) {
      throw const FormatException('YOLOX output anchor count does not match input size.');
    }

    final candidates = <_Candidate>[];
    for (var anchor = 0; anchor < anchorCount; anchor++) {
      final base = anchor * 85;
      final (gridX, gridY, stride) = grid[anchor];
      final centerX = (values[base] + gridX) * stride;
      final centerY = (values[base + 1] + gridY) * stride;
      final boxWidth = _safeExp(values[base + 2]) * stride;
      final boxHeight = _safeExp(values[base + 3]) * stride;
      final objectness = values[base + 4];
      if (!objectness.isFinite || objectness < 0 || objectness > 1) continue;

      var classId = 0;
      var classScore = -1.0;
      for (var id = 0; id < 80; id++) {
        final score = values[base + 5 + id];
        if (score.isFinite && score > classScore) {
          classScore = score;
          classId = id;
        }
      }
      final confidence = objectness * classScore;
      if (confidence < confidenceThreshold || classScore < 0 || classScore > 1) continue;

      final x1 = ((centerX - boxWidth / 2) / scale)
          .clamp(0.0, sourceWidth.toDouble()).toDouble();
      final y1 = ((centerY - boxHeight / 2) / scale)
          .clamp(0.0, sourceHeight.toDouble()).toDouble();
      final x2 = ((centerX + boxWidth / 2) / scale)
          .clamp(0.0, sourceWidth.toDouble()).toDouble();
      final y2 = ((centerY + boxHeight / 2) / scale)
          .clamp(0.0, sourceHeight.toDouble()).toDouble();
      if (x2 <= x1 || y2 <= y1) continue;
      candidates.add(_Candidate(classId, confidence, x1, y1, x2, y2));
    }

    candidates.sort((a, b) => b.confidence.compareTo(a.confidence));
    final selected = <_Candidate>[];
    for (final candidate in candidates) {
      if (selected.any((kept) => kept.classId == candidate.classId &&
          _intersectionOverUnion(kept, candidate) > 0.45)) continue;
      selected.add(candidate);
      if (selected.length == 100) break;
    }
    return [
      for (final item in selected)
        NativeDetection(
          category: item.classId == 0 ? DetectionCategory.person :
              _vehicleClasses.contains(item.classId) ? DetectionCategory.vehicle :
              _animalClasses.contains(item.classId) ? DetectionCategory.animal :
              DetectionCategory.object,
          label: classes[item.classId],
          confidence: item.confidence,
          x: item.x1 / sourceWidth,
          y: item.y1 / sourceHeight,
          width: (item.x2 - item.x1) / sourceWidth,
          height: (item.y2 - item.y1) / sourceHeight,
        ),
    ];
  }

  static double _scale(int width, int height, int targetWidth, int targetHeight) =>
      (targetWidth / width < targetHeight / height
          ? targetWidth / width : targetHeight / height);

  static double _safeExp(double value) {
    if (!value.isFinite) return 0;
    return math.exp(value.clamp(-10.0, 10.0).toDouble());
  }

  static double _intersectionOverUnion(_Candidate a, _Candidate b) {
    final left = a.x1 > b.x1 ? a.x1 : b.x1;
    final top = a.y1 > b.y1 ? a.y1 : b.y1;
    final right = a.x2 < b.x2 ? a.x2 : b.x2;
    final bottom = a.y2 < b.y2 ? a.y2 : b.y2;
    final intersection = (right - left).clamp(0.0, double.infinity) *
        (bottom - top).clamp(0.0, double.infinity);
    final areaA = (a.x2 - a.x1) * (a.y2 - a.y1);
    final areaB = (b.x2 - b.x1) * (b.y2 - b.y1);
    final union = areaA + areaB - intersection;
    return union <= 0 ? 0 : intersection / union;
  }

  @override
  Future<void> dispose() async {
    await _session?.close();
    _session = null;
  }
}

class _Candidate {
  final int classId;
  final double confidence;
  final double x1;
  final double y1;
  final double x2;
  final double y2;

  const _Candidate(this.classId, this.confidence, this.x1, this.y1, this.x2, this.y2);
}
