import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Isolated training environment. Never sends commands to an aircraft.
class SimulationOpsPage extends StatefulWidget {
  const SimulationOpsPage({super.key});
  @override
  State<SimulationOpsPage> createState() => _SimulationOpsPageState();
}

class _SimulationOpsPageState extends State<SimulationOpsPage> {
  final List<LatLng> route = [];
  final List<String> events = [];
  final List<String> observations = [];
  final TextEditingController note = TextEditingController();
  LatLng position = const LatLng(41.9981, 21.4254);
  bool running = false;
  bool signalLost = false;
  int battery = 100;
  double altitude = 0;
  double speed = 0;
  int steps = 0;
  String role = 'Observer';

  void log(String message) {
    events.insert(0, '${DateTime.now().toIso8601String().substring(0, 19)}  $message');
  }

  void start() => setState(() {
    running = true;
    signalLost = false;
    battery = 100;
    altitude = 25;
    speed = 4;
    steps = 0;
    route..clear()..add(position);
    log('SIMULATION STARTED');
  });

  void advance() => setState(() {
    if (!running || signalLost) return;
    if (battery <= 5) {
      running = false;
      speed = 0;
      log('LOW BATTERY: simulation halted');
      return;
    }
    steps++;
    final angle = steps * math.pi / 5;
    position = LatLng(position.latitude + math.cos(angle) * .0003,
        position.longitude + math.sin(angle) * .0003);
    route.add(position);
    battery = math.max(0, battery - 3);
    altitude = 25 + (steps % 4) * 2;
    speed = 3 + (steps % 3).toDouble();
    log('SIMULATED TELEMETRY STEP $steps');
  });

  void signalScenario() => setState(() {
    if (!running) return;
    signalLost = true;
    speed = 0;
    log('SIGNAL LOSS INJECTED - virtual vehicle held');
  });

  void recover() => setState(() {
    signalLost = false;
    log('SIMULATED LINK RESTORED');
  });

  void stop() => setState(() {
    running = false;
    speed = 0;
    altitude = 0;
    log('SIMULATION STOPPED');
  });

  void addObservation() {
    final value = note.text.trim();
    if (value.isEmpty) return;
    setState(() {
      observations.insert(0, 'UNVERIFIED • $value • step $steps');
      log('Observation recorded for human review');
      note.clear();
    });
  }

  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canOperate = role == 'Operator';
    return ListView(padding: const EdgeInsets.all(18), children: [
      const Text('SIMULATION OPERATIONS', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      const SizedBox(height: 5),
      const Text('TRAINING ONLY • No physical drone connection • No biometric identification'),
      const SizedBox(height: 16),
      DropdownButtonFormField<String>(
        initialValue: role,
        decoration: const InputDecoration(labelText: 'Demo role (not authentication)', border: OutlineInputBorder()),
        items: const [
          DropdownMenuItem(value: 'Observer', child: Text('Observer — read only')),
          DropdownMenuItem(value: 'Operator', child: Text('Operator — simulator controls')),
        ],
        onChanged: (v) => setState(() => role = v ?? 'Observer'),
      ),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: [
        FilledButton(onPressed: canOperate && !running ? start : null, child: const Text('START SIMULATION')),
        OutlinedButton(onPressed: canOperate && running && !signalLost ? advance : null, child: const Text('ADVANCE STEP')),
        OutlinedButton(onPressed: canOperate && running && !signalLost ? signalScenario : null, child: const Text('INJECT SIGNAL LOSS')),
        OutlinedButton(onPressed: canOperate && signalLost ? recover : null, child: const Text('RESTORE LINK')),
        OutlinedButton(onPressed: canOperate && running ? stop : null, child: const Text('STOP')),
      ]),
      const SizedBox(height: 12),
      Wrap(spacing: 10, runSpacing: 10, children: [
        _stat('MODE', running ? 'SIMULATING' : 'IDLE'),
        _stat('BATTERY', '$battery%'),
        _stat('ALTITUDE', '${altitude.toStringAsFixed(0)} m'),
        _stat('SPEED', '${speed.toStringAsFixed(1)} m/s'),
        _stat('LINK', signalLost ? 'LOST (SIM)' : 'LOCAL SIM'),
        _stat('GPS', '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}'),
      ]),
      const SizedBox(height: 14),
      SizedBox(height: 290, child: ClipRRect(borderRadius: BorderRadius.circular(12),
        child: FlutterMap(options: MapOptions(initialCenter: position, initialZoom: 14),
          children: [
            TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'org.sarisa.training'),
            if (route.length > 1) PolylineLayer(polylines: [
              Polyline(points: route, strokeWidth: 4, color: Colors.lightBlueAccent),
            ]),
            MarkerLayer(markers: [
              Marker(point: position, width: 45, height: 45,
                child: const Icon(Icons.flight, color: Colors.lightGreenAccent, size: 34)),
            ]),
            const RichAttributionWidget(attributions: [TextSourceAttribution('© OpenStreetMap contributors')]),
          ]))),
      const SizedBox(height: 18),
      const Text('HUMAN-REVIEWED OBSERVATIONS', style: TextStyle(fontWeight: FontWeight.bold)),
      const Text('Manual notes only. No automatic person matching, tracking or identification.'),
      const SizedBox(height: 8),
      TextField(controller: note, maxLength: 180,
        decoration: const InputDecoration(border: OutlineInputBorder(),
          hintText: 'e.g. stationary vehicle near search sector')),
      FilledButton(onPressed: canOperate ? addObservation : null, child: const Text('RECORD OBSERVATION')),
      ...observations.map((o) => ListTile(leading: const Icon(Icons.fact_check_outlined), title: Text(o))),
      const SizedBox(height: 16),
      const Text('SESSION AUDIT EVENTS', style: TextStyle(fontWeight: FontWeight.bold)),
      const Text('Events and observations are held in memory for this demo session; they are not durable audit logs.'),
      ...events.map((e) => ListTile(dense: true, leading: const Icon(Icons.history), title: Text(e))),
    ]);
  }

  Widget _stat(String name, String value) => SizedBox(width: 165,
    child: Card(child: Padding(padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(name, style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
        const SizedBox(height: 5),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ]))));
}
