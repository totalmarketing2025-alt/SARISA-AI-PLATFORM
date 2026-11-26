import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Converts Android CameraX YUV420 frames to a small RGB image off the UI
/// isolate. Pixel and row strides vary by device, so both are honored.
Future<img.Image> cameraFrameToRgb(CameraImage frame, {int maxDimension = 640}) async {
  if (frame.format.group != ImageFormatGroup.yuv420 || frame.planes.length < 3) {
    throw const FormatException('Live camera must provide YUV420 frames.');
  }
  final converted = await compute(convertYuv420Planes, <String, Object>{
    'width': frame.width,
    'height': frame.height,
    'maxDimension': maxDimension,
    'y': frame.planes[0].bytes,
    'u': frame.planes[1].bytes,
    'v': frame.planes[2].bytes,
    'yRowStride': frame.planes[0].bytesPerRow,
    'uRowStride': frame.planes[1].bytesPerRow,
    'vRowStride': frame.planes[2].bytesPerRow,
    'yPixelStride': frame.planes[0].bytesPerPixel ?? 1,
    'uPixelStride': frame.planes[1].bytesPerPixel ?? 1,
    'vPixelStride': frame.planes[2].bytesPerPixel ?? 1,
  });
  return img.Image.fromBytes(
    width: converted['width']! as int,
    height: converted['height']! as int,
    bytes: Uint8List.fromList(converted['rgb']! as List<int>).buffer,
    order: img.ChannelOrder.rgb,
    numChannels: 3,
  );
}

Map<String, Object> convertYuv420Planes(Map<String, Object> input) {
  final width = input['width']! as int;
  final height = input['height']! as int;
  final limit = input['maxDimension']! as int;
  if (width <= 0 || height <= 0 || limit <= 0) {
    throw const FormatException('Invalid live camera frame dimensions.');
  }
  final scale = (width > height ? width : height) / limit;
  final outWidth = (width / scale).round().clamp(1, limit).toInt();
  final outHeight = (height / scale).round().clamp(1, limit).toInt();
  final y = input['y']! as Uint8List;
  final u = input['u']! as Uint8List;
  final v = input['v']! as Uint8List;
  final yRow = input['yRowStride']! as int;
  final uRow = input['uRowStride']! as int;
  final vRow = input['vRowStride']! as int;
  final yPixel = input['yPixelStride']! as int;
  final uPixel = input['uPixelStride']! as int;
  final vPixel = input['vPixelStride']! as int;
  final rgb = Uint8List(outWidth * outHeight * 3);
  var target = 0;
  for (var outY = 0; outY < outHeight; outY++) {
    final sourceY = (outY * height / outHeight).floor();
    for (var outX = 0; outX < outWidth; outX++) {
      final sourceX = (outX * width / outWidth).floor();
      final yi = sourceY * yRow + sourceX * yPixel;
      final uvX = sourceX ~/ 2;
      final uvY = sourceY ~/ 2;
      final ui = uvY * uRow + uvX * uPixel;
      final vi = uvY * vRow + uvX * vPixel;
      if (yi >= y.length || ui >= u.length || vi >= v.length) {
        throw const FormatException('Camera returned truncated YUV420 planes.');
      }
      final luminance = y[yi].toDouble();
      final cb = u[ui].toDouble() - 128;
      final cr = v[vi].toDouble() - 128;
      rgb[target++] = (luminance + 1.402 * cr).round().clamp(0, 255).toInt();
      rgb[target++] = (luminance - 0.344136 * cb - 0.714136 * cr)
          .round().clamp(0, 255).toInt();
      rgb[target++] = (luminance + 1.772 * cb).round().clamp(0, 255).toInt();
    }
  }
  return {'width': outWidth, 'height': outHeight, 'rgb': rgb};
}
