import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:sarisa/features/missions/models/mission_plan.dart';

void main() {
  final plan = const MissionPlan(
    id: 'mission-1', name: 'Search sector A', notes: 'Training mission',
    status: 'DRAFT', createdAt: '2026-11-10T00:00:00Z',
    waypoints: const [LatLng(41.9981, 21.4254), LatLng(42.0, 21.43)],
    searchArea: const [LatLng(41.99, 21.42), LatLng(42.0, 21.42), LatLng(42.0, 21.44)],
    history: const ['Mission created'],
  );

  test('mission JSON roundtrip preserves routes and area', () {
    final decoded = MissionPlan.decodeAll(MissionPlan.encodeAll([plan]));
    expect(decoded, hasLength(1));
    expect(decoded.single.name, 'Search sector A');
    expect(decoded.single.waypoints, hasLength(2));
    expect(decoded.single.searchArea, hasLength(3));
    expect(decoded.single.status, 'DRAFT');
  });

  test('status updates preserve geometry and append history', () {
    final changed = plan.copyWith(status: 'ACTIVE',
      history: [...plan.history, 'Activated']);
    expect(changed.status, 'ACTIVE');
    expect(changed.waypoints, hasLength(2));
    expect(changed.history.last, 'Activated');
    expect(plan.status, 'DRAFT');
  });

  test('invalid latitude is rejected on load', () {
    const invalid = '[{"id":"x","name":"X","createdAt":"now",'
      '"waypoints":[[100,21]],"searchArea":[],"history":[]}]';
    expect(() => MissionPlan.decodeAll(invalid), throwsFormatException);
  });
}
