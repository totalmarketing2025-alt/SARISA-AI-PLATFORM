import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// Creates parallel in-area search passes. Each pass remains a separate
/// segment so an autopilot cannot infer an unsafe straight connector.
class SearchAreaRoutePlanner {
  static List<List<LatLng>> planSweepTracks(List<LatLng> polygon, {
    double spacingMeters = 50,
    int maxTracks = 500,
  }) {
    if (polygon.length < 3 || !spacingMeters.isFinite || spacingMeters < 5 ||
        spacingMeters > 2000 || maxTracks < 1) {
      throw ArgumentError('A polygon and valid sweep spacing are required.');
    }
    final referenceLatitude = polygon
        .map((point) => point.latitude).reduce((a, b) => a + b) / polygon.length;
    final cosLatitude = math.cos(referenceLatitude * math.pi / 180);
    final xy = polygon.map((point) => _Point(
      point.longitude * 111320 * cosLatitude,
      point.latitude * 110574,
    )).toList(growable: false);
    final minY = xy.map((point) => point.y).reduce((a, b) => a < b ? a : b);
    final maxY = xy.map((point) => point.y).reduce((a, b) => a > b ? a : b);
    if (maxY - minY < 1) return const [];

    final tracks = <List<LatLng>>[];
    var row = 0;
    var scanY = minY + spacingMeters / 2;
    if (scanY >= maxY) scanY = (minY + maxY) / 2;
    while (scanY < maxY && tracks.length < maxTracks) {
      final intersections = <double>[];
      for (var index = 0; index < xy.length; index++) {
        final start = xy[index];
        final end = xy[(index + 1) % xy.length];
        final crosses = (start.y <= scanY && end.y > scanY) ||
            (end.y <= scanY && start.y > scanY);
        if (!crosses) continue;
        intersections.add(start.x + (scanY - start.y) *
            (end.x - start.x) / (end.y - start.y));
      }
      intersections.sort();
      final intervals = <(double, double)>[];
      for (var index = 0; index + 1 < intersections.length; index += 2) {
        if (intersections[index + 1] - intersections[index] > 1) {
          intervals.add((intersections[index], intersections[index + 1]));
        }
      }
      if (row.isOdd) {
        final reversed = intervals.reversed.toList();
        intervals
          ..clear()
          ..addAll(reversed);
      }
      for (var index = 0; index < intervals.length && tracks.length < maxTracks;
          index++) {
        final (left, right) = intervals[index];
        final reverse = row.isOdd ? index.isEven : index.isOdd;
        final firstX = reverse ? right : left;
        final secondX = reverse ? left : right;
        tracks.add([
          _toLatLng(_Point(firstX, scanY), cosLatitude),
          _toLatLng(_Point(secondX, scanY), cosLatitude),
        ]);
      }
      row++;
      scanY = minY + spacingMeters / 2 + row * spacingMeters;
    }
    if (tracks.isEmpty) {
      final centerY = (minY + maxY) / 2;
      final intersections = _intersectionsAt(xy, centerY);
      if (intersections.length >= 2) {
        tracks.add([
          _toLatLng(_Point(intersections.first, centerY), cosLatitude),
          _toLatLng(_Point(intersections.last, centerY), cosLatitude),
        ]);
      }
    }
    return tracks;
  }

  static List<double> _intersectionsAt(List<_Point> polygon, double y) {
    final xs = <double>[];
    for (var index = 0; index < polygon.length; index++) {
      final start = polygon[index];
      final end = polygon[(index + 1) % polygon.length];
      if ((start.y <= y && end.y > y) || (end.y <= y && start.y > y)) {
        xs.add(start.x + (y - start.y) * (end.x - start.x) /
            (end.y - start.y));
      }
    }
    xs.sort();
    return xs;
  }

  static LatLng _toLatLng(_Point point, double cosLatitude) => LatLng(
    point.y / 110574,
    point.x / (111320 * cosLatitude),
  );
}

class _Point {
  final double x;
  final double y;
  const _Point(this.x, this.y);
}
