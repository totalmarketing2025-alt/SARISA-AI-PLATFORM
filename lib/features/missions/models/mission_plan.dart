import 'dart:convert';
import 'package:latlong2/latlong.dart';

class MissionPlan {
  final String id;
  final String name;
  final String notes;
  final String status;
  final String createdAt;
  final List<LatLng> waypoints;
  final List<LatLng> searchArea;
  final List<String> history;

  const MissionPlan({required this.id, required this.name, required this.notes,
    required this.status, required this.createdAt, required this.waypoints,
    required this.searchArea, required this.history});

  MissionPlan copyWith({String? status, List<LatLng>? waypoints, List<LatLng>? searchArea,
    List<String>? history}) => MissionPlan(id: id, name: name, notes: notes,
    status: status ?? this.status, createdAt: createdAt,
    waypoints: waypoints ?? this.waypoints, searchArea: searchArea ?? this.searchArea,
    history: history ?? this.history);

  static List<LatLng> _points(dynamic raw) => (raw as List<dynamic>).map((p) {
    final pair = p as List<dynamic>;
    final lat = (pair[0] as num).toDouble();
    final lng = (pair[1] as num).toDouble();
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
      throw const FormatException('Invalid coordinate');
    }
    return LatLng(lat, lng);
  }).toList();

  static List<List<double>> _encodePoints(List<LatLng> points) =>
      points.map((p) => [p.latitude, p.longitude]).toList();

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'notes': notes, 'status': status,
    'createdAt': createdAt, 'waypoints': _encodePoints(waypoints),
    'searchArea': _encodePoints(searchArea), 'history': history,
  };

  factory MissionPlan.fromJson(Map<String, dynamic> json) => MissionPlan(
    id: json['id'] as String, name: json['name'] as String,
    notes: json['notes'] as String? ?? '',
    status: json['status'] as String? ?? 'DRAFT',
    createdAt: json['createdAt'] as String,
    waypoints: _points(json['waypoints'] ?? []),
    searchArea: _points(json['searchArea'] ?? []),
    history: (json['history'] as List<dynamic>? ?? []).cast<String>(),
  );

  static String encodeAll(List<MissionPlan> missions) =>
      jsonEncode(missions.map((m) => m.toJson()).toList());

  static List<MissionPlan> decodeAll(String raw) =>
      (jsonDecode(raw) as List<dynamic>).map((m) =>
        MissionPlan.fromJson(Map<String, dynamic>.from(m as Map))).toList();
}
