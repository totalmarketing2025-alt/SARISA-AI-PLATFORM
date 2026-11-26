import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:sarisa/features/missions/models/mission_plan.dart';
import 'package:sarisa/features/missions/services/search_area_route_planner.dart';

void main() {
  test('builds parallel sweep tracks within a rectangular search area', () {
    final area = [
      const LatLng(41.0, 21.0),
      const LatLng(41.0, 21.002),
      const LatLng(41.002, 21.002),
      const LatLng(41.002, 21.0),
    ];

    final tracks = SearchAreaRoutePlanner.planSweepTracks(area,
        spacingMeters: 50);

    expect(tracks.length, greaterThan(1));
    for (final track in tracks) {
      expect(track, hasLength(2));
      for (final point in track) {
        expect(point.latitude, inInclusiveRange(41.0, 41.002));
        expect(point.longitude, inInclusiveRange(21.0, 21.002));
      }
    }
  });

  test('rejects invalid spacing and insufficient boundary points', () {
    expect(() => SearchAreaRoutePlanner.planSweepTracks(const [],
        spacingMeters: 50), throwsArgumentError);
    expect(() => SearchAreaRoutePlanner.planSweepTracks([
      const LatLng(41, 21), const LatLng(41.1, 21.1), const LatLng(41.2, 21),
    ], spacingMeters: 1), throwsArgumentError);
  });

  test('mission storage round-trips drone search tracks and spacing', () {
    const area = [LatLng(41, 21), LatLng(41, 21.01), LatLng(41.01, 21.01)];
    const tracks = [[LatLng(41.001, 21.002), LatLng(41.001, 21.008)]];
    const mission = MissionPlan(id: 'sar-test', name: 'Search', notes: '',
      status: 'DRAFT', createdAt: '2026-11-27T00:00:00Z', waypoints: [],
      searchArea: area, searchTracks: tracks, laneSpacingMeters: 25,
      history: []);

    final restored = MissionPlan.decodeAll(MissionPlan.encodeAll([mission])).single;

    expect(restored.searchArea, area);
    expect(restored.searchTracks, tracks);
    expect(restored.laneSpacingMeters, 25);
  });
}
