import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/mission_plan.dart';
import '../services/mission_repository.dart';
import '../services/search_area_route_planner.dart';

class MissionPlanningPage extends StatefulWidget {
  const MissionPlanningPage({super.key});
  @override
  State<MissionPlanningPage> createState() => _MissionPlanningPageState();
}

class _MissionPlanningPageState extends State<MissionPlanningPage> {
  final repository = MissionRepository();
  final name = TextEditingController();
  final notes = TextEditingController();
  final mapController = MapController();
  List<MissionPlan> missions = [];
  MissionPlan? selected;
  String mode = 'WAYPOINT';
  bool _drawingArea = false;
  List<LatLng> _areaDraft = [];
  double _laneSpacingMeters = 50;
  bool busy = false;
  Future<void> _writeQueue = Future<void>.value();
  String? error;

  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try {
      final loaded = await repository.load();
      if (mounted) setState(() { missions = loaded; error = null; });
    } catch (e) {
      if (mounted) setState(() => error = 'Could not load missions: $e');
    }
  }

  void _create() {
    if (name.text.trim().isEmpty) return;
    final mission = MissionPlan(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name.text.trim(), notes: notes.text.trim(), status: 'DRAFT',
      createdAt: DateTime.now().toUtc().toIso8601String(),
      waypoints: [], searchArea: [],
      history: ['Mission created at ${DateTime.now().toUtc().toIso8601String()}'],
    );
    setState(() { missions = [...missions, mission]; selected = mission; });
    name.clear(); notes.clear(); _persist();
  }

  void _change(MissionPlan next) {
    setState(() {
      missions = [for (final m in missions) if (m.id == next.id) next else m];
      selected = next;
    });
    _persist();
  }

  void _addPoint(LatLng point) {
    final current = selected;
    if (current == null || current.status == 'COMPLETED') return;
    if (mode == 'WAYPOINT' && current.waypoints.length >= 100) return;
    if (mode == 'AREA' && current.searchArea.length >= 100) return;
    if (mode == 'DRAW_AREA') return;
    final timestamp = DateTime.now().toUtc().toIso8601String();
    _change(current.copyWith(
      waypoints: mode == 'WAYPOINT' ? [...current.waypoints, point] : null,
      searchArea: mode == 'AREA' ? [...current.searchArea, point] : null,
      searchTracks: mode == 'AREA' ? <List<LatLng>>[] : null,
      history: [...current.history, '$mode point added at $timestamp'],
    ));
  }

  void _beginAreaStroke(LatLng point) {
    if (mode != 'DRAW_AREA' || selected?.status == 'COMPLETED') return;
    setState(() {
      _drawingArea = true;
      _areaDraft = [point];
      error = null;
    });
  }

  void _extendAreaStroke(LatLng point) {
    if (!_drawingArea || _areaDraft.length >= 300) return;
    if (_distanceMeters(_areaDraft.last, point) < 8) return;
    setState(() => _areaDraft = [..._areaDraft, point]);
  }

  void _finishAreaStroke(LatLng point) {
    if (!_drawingArea) return;
    _extendAreaStroke(point);
    setState(() => _drawingArea = false);
    _saveSearchArea(_areaDraft);
  }

  void _saveSearchArea(List<LatLng> polygon) {
    final current = selected;
    if (current == null || current.status == 'COMPLETED') return;
    if (polygon.length < 3) {
      setState(() => error = 'Draw or add at least three points to create a search area.');
      return;
    }
    try {
      final tracks = SearchAreaRoutePlanner.planSweepTracks(polygon,
          spacingMeters: _laneSpacingMeters);
      if (tracks.isEmpty) {
        setState(() => error = 'That area is too small or too narrow for a search pass.');
        return;
      }
      _change(current.copyWith(searchArea: List<LatLng>.of(polygon),
        searchTracks: tracks,
        laneSpacingMeters: _laneSpacingMeters,
        history: [...current.history,
          'Search boundary saved; generated ${tracks.length} sweep tracks at '
          '${_laneSpacingMeters.round()} m spacing at ${DateTime.now().toUtc().toIso8601String()}']));
      setState(() { _areaDraft = []; error = null; });
    } catch (e) {
      setState(() => error = 'Could not create drone search tracks: $e');
    }
  }

  static double _distanceMeters(LatLng a, LatLng b) {
    const metersPerDegreeLat = 110574.0;
    final latitudeScale = 111320.0 *
        (a.latitude + b.latitude) / 2 * 3.141592653589793 / 180;
    final dx = (a.longitude - b.longitude) * latitudeScale;
    final dy = (a.latitude - b.latitude) * metersPerDegreeLat;
    return math.sqrt(dx * dx + dy * dy);
  }

  void _status(String status) {
    final current = selected;
    if (current == null || current.status == 'COMPLETED') return;
    _change(current.copyWith(status: status, history: [
      ...current.history, 'Status changed to $status at ${DateTime.now().toUtc().toIso8601String()}',
    ]));
  }

  Future<void> _persist() {
    final snapshot = List<MissionPlan>.of(missions);
    if (mounted) setState(() { busy = true; error = null; });
    _writeQueue = _writeQueue.then((_) => repository.save(snapshot)).catchError((Object e) {
      if (mounted) setState(() => error = 'Save failed: $e');
    }).whenComplete(() {
      if (mounted) setState(() => busy = false);
    });
    return _writeQueue;
  }

  @override
  void dispose() { name.dispose(); notes.dispose(); mapController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final mission = selected;
    return ListView(padding: const EdgeInsets.all(18), children: [
      const Text('MISSION PLANNING & MAPPING',
        style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
      const Text('Planning only • map taps do not control aircraft'),
      const SizedBox(height: 12),
      TextField(controller: name, maxLength: 100,
        decoration: const InputDecoration(labelText: 'Mission name', border: OutlineInputBorder())),
      TextField(controller: notes, maxLength: 500, maxLines: 2,
        decoration: const InputDecoration(labelText: 'Search area / notes', border: OutlineInputBorder())),
      FilledButton.icon(onPressed: busy ? null : _create,
        icon: const Icon(Icons.add), label: const Text('CREATE MISSION DRAFT')),
      if (error != null) Text(error!, style: const TextStyle(color: Colors.orangeAccent)),
      if (busy) const LinearProgressIndicator(),
      const SizedBox(height: 10),
      DropdownButtonFormField<String>(
        key: ValueKey(mission?.id ?? 'none'),
        initialValue: mission?.id,
        decoration: const InputDecoration(labelText: 'Select saved mission', border: OutlineInputBorder()),
        items: missions.map((m) => DropdownMenuItem(value: m.id,
          child: Text('${m.name} — ${m.status}', overflow: TextOverflow.ellipsis))).toList(),
        onChanged: (id) => setState(() {
          selected = missions.where((m) => m.id == id).firstOrNull;
          _areaDraft = [];
          _drawingArea = false;
        }),
      ),
      if (mission != null) ...[
        const SizedBox(height: 12),
        Text('STATUS: ${mission.status}'),
        Wrap(spacing: 8, children: [
          OutlinedButton(onPressed: mission.status == 'DRAFT' ? () => _status('ACTIVE') : null,
            child: const Text('ACTIVATE')),
          OutlinedButton(onPressed: mission.status == 'ACTIVE' ? () => _status('COMPLETED') : null,
            child: const Text('COMPLETE')),
          OutlinedButton(onPressed: mission.status != 'COMPLETED' ? () {
            _areaDraft = [];
            _change(mission.copyWith(waypoints: [], searchArea: [], searchTracks: [],
              history: [...mission.history, 'Map cleared at ${DateTime.now().toUtc().toIso8601String()}']));
          } : null, child: const Text('CLEAR MAP')),
        ]),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'WAYPOINT', label: Text('Waypoints'), icon: Icon(Icons.route)),
            ButtonSegment(value: 'AREA', label: Text('Tap boundary'), icon: Icon(Icons.crop_free)),
            ButtonSegment(value: 'DRAW_AREA', label: Text('Draw with finger'), icon: Icon(Icons.gesture)),
          ],
          selected: {mode}, onSelectionChanged: (v) => setState(() {
            mode = v.first;
            _drawingArea = false;
            _areaDraft = [];
          }),
        ),
        const SizedBox(height: 8),
        if (mode == 'WAYPOINT')
          const Text('Tap map to add a manual waypoint.'),
        if (mode == 'AREA')
          const Text('Tap boundary vertices, then generate the search tracks.'),
        if (mode == 'DRAW_AREA')
          const Text('Drag your finger around the search boundary. The map is locked while drawing.'),
        if (mode != 'WAYPOINT') ...[
          Row(children: [
            const Expanded(child: Text('Search pass spacing')),
            DropdownButton<double>(
              value: _laneSpacingMeters,
              items: const [25.0, 50.0, 100.0].map((spacing) =>
                DropdownMenuItem(value: spacing, child: Text('${spacing.round()} m'))).toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() => _laneSpacingMeters = value);
              },
            ),
          ]),
          if (mode == 'AREA')
            OutlinedButton.icon(onPressed: () => _saveSearchArea(
              selected?.searchArea ?? const []),
              icon: const Icon(Icons.route), label: const Text('GENERATE SEARCH TRACKS')),
        ],
        SizedBox(height: 340, child: FlutterMap(
          mapController: mapController,
          options: MapOptions(initialCenter: const LatLng(41.9981, 21.4254),
            initialZoom: 12,
            interactionOptions: InteractionOptions(flags: mode == 'DRAW_AREA'
                ? InteractiveFlag.none : InteractiveFlag.all),
            onTap: (_, point) => _addPoint(point),
            onPointerDown: (_, point) => _beginAreaStroke(point),
            onPointerMove: (_, point) => _extendAreaStroke(point),
            onPointerUp: (_, point) => _finishAreaStroke(point),
            onPointerCancel: (_) {
              if (_drawingArea) setState(() { _drawingArea = false; _areaDraft = []; });
            }),
          children: [
            TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'org.sarisa.missions'),
            if (mission.searchArea.length >= 3)
              PolygonLayer(polygons: [Polygon(points: mission.searchArea,
                color: Colors.lightBlue.withValues(alpha: .15),
                borderColor: Colors.lightBlue, borderStrokeWidth: 2)]),
            if (mission.waypoints.length >= 2)
              PolylineLayer(polylines: [Polyline(points: mission.waypoints,
                color: Colors.lightGreenAccent, strokeWidth: 3)]),
            if (mission.searchTracks.isNotEmpty)
              PolylineLayer(polylines: [
                for (final track in mission.searchTracks)
                  Polyline(points: track, color: Colors.amberAccent, strokeWidth: 3),
              ]),
            if (_areaDraft.length >= 2)
              PolylineLayer(polylines: [Polyline(points: _areaDraft,
                color: Colors.deepOrangeAccent, strokeWidth: 3)]),
            MarkerLayer(markers: [
              for (var i = 0; i < mission.waypoints.length; i++)
                Marker(point: mission.waypoints[i], width: 36, height: 36,
                  child: CircleAvatar(radius: 16, child: Text('${i + 1}'))),
              if (mode == 'AREA') for (final p in mission.searchArea)
                Marker(point: p, width: 20, height: 20,
                  child: const Icon(Icons.circle, color: Colors.lightBlue, size: 14)),
            ]),
            const RichAttributionWidget(attributions: [
              TextSourceAttribution('© OpenStreetMap contributors')]),
          ],
        )),
        const SizedBox(height: 12),
        Text('Manual waypoints: ${mission.waypoints.length} • Search boundary points: ${mission.searchArea.length} • Drone search tracks: ${mission.searchTracks.length}'),
        if (mission.searchTracks.isNotEmpty)
          Text('Sweep spacing: ${mission.laneSpacingMeters.round()} m • route saved with this mission',
            style: const TextStyle(color: Colors.lightGreen)),
        const SizedBox(height: 8),
        const Text('MISSION HISTORY', style: TextStyle(fontWeight: FontWeight.bold)),
        ...mission.history.reversed.map((event) => ListTile(
          dense: true, leading: const Icon(Icons.history), title: Text(event))),
      ],
      const SizedBox(height: 10),
      const Text('The generated search tracks are saved to the mission for drone planning. This screen does not send flight commands to aircraft.'),
    ]);
  }
}
