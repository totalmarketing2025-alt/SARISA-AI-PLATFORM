import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sarisa/features/ai/services/camera_frame_converter.dart';

void main() {
  group('convertYuv420Planes', () {
    test('converts a neutral 2x2 YUV frame to grayscale RGB', () {
      final result = convertYuv420Planes({
        'width': 2,
        'height': 2,
        'maxDimension': 640,
        'y': Uint8List.fromList([128, 128, 128, 128]),
        'u': Uint8List.fromList([128]),
        'v': Uint8List.fromList([128]),
        'yRowStride': 2,
        'uRowStride': 1,
        'vRowStride': 1,
        'yPixelStride': 1,
        'uPixelStride': 1,
        'vPixelStride': 1,
      });

      expect(result['width'], 2);
      expect(result['height'], 2);
      expect(result['rgb'], List<int>.filled(12, 128));
    });

    test('honors row and pixel strides', () {
      final result = convertYuv420Planes({
        'width': 2,
        'height': 2,
        'maxDimension': 640,
        'y': Uint8List.fromList([100, 0, 100, 0, 100, 0, 100]),
        'u': Uint8List.fromList([128, 0]),
        'v': Uint8List.fromList([128, 0]),
        'yRowStride': 4,
        'uRowStride': 2,
        'vRowStride': 2,
        'yPixelStride': 2,
        'uPixelStride': 2,
        'vPixelStride': 2,
      });

      expect(result['rgb'], List<int>.filled(12, 100));
    });

    test('rejects truncated camera planes', () {
      expect(() => convertYuv420Planes({
        'width': 2,
        'height': 2,
        'maxDimension': 640,
        'y': Uint8List.fromList([128]),
        'u': Uint8List.fromList([128]),
        'v': Uint8List.fromList([128]),
        'yRowStride': 2,
        'uRowStride': 1,
        'vRowStride': 1,
        'yPixelStride': 1,
        'uPixelStride': 1,
        'vPixelStride': 1,
      }), throwsFormatException);
    });
  });
}
