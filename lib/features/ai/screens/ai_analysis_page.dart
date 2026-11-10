import 'package:flutter/material.dart';
import '../models/ai_finding.dart';
import '../services/ai_finding_repository.dart';

/// Phase 11 operator review workspace. Live inference is not connected yet.
class AiAnalysisPage extends StatefulWidget {
  const AiAnalysisPage({super.key});
  @override
  State<AiAnalysisPage> createState() => _AiAnalysisPageState();
}

class _AiAnalysisPageState extends State<AiAnalysisPage> {
  final AiFindingRepository _repository = AiFindingRepository();
  final TextEditingController _source = TextEditingController(text: 'SIMULATOR CAM 01');
  final TextEditingController _mission = TextEditingController();
  final TextEditingController _notes = TextEditingController();
  List<AiFinding> _findings = [];
  Set<DetectionCategory> _enabled = DetectionCategory.values.toSet();
  double _threshold = 0.75;
  String _mode = 'balanced';
  ReviewStatus? _filter;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final findings = await _repository.load();
      if (mounted) setState(() => _findings = findings);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not read saved AI findings.');
    }
  }

  Future<void> _persist() async {
    try {
      await _repository.save(_findings);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not save findings to this device.');
    }
  }

  Future<void> _simulate() async {
    if (_busy) return;
    setState(() { _busy = true; _error = null; });
    try {
      final settings = AiAnalysisSettings(
        threshold: _threshold, enabled: _enabled, mode: _mode);
      final newFindings = SimulatedDetectionEngine.sample(
        _source.text.trim().isEmpty ? 'SIMULATOR CAM 01' : _source.text.trim(),
        settings);
      setState(() => _findings = [...newFindings, ..._findings].take(200).toList());
      await _persist();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _review(AiFinding finding, ReviewStatus status) async {
    final notes = _notes.text.trim();
    final missionId = _mission.text.trim();
    setState(() {
      _findings = _findings.map((item) => item.id == finding.id
        ? item.copyWith(status: status, notes: notes, missionId: missionId)
        : item).toList();
    });
    await _persist();
  }

  @override
  void dispose() {
    _source.dispose();
    _mission.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visible = _findings.where((finding) =>
      _filter == null || finding.status == _filter).toList();
    final pending = _findings.where((finding) =>
      finding.status == ReviewStatus.pending).length;
    final verified = _findings.where((finding) =>
      finding.status == ReviewStatus.verified).length;

    return ListView(padding: const EdgeInsets.all(20), children: [
      const Text('AI VISUAL ANALYSIS', style: TextStyle(
        fontSize: 22, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      const Text('PHASE 11 • Operator-supervised findings and event review'),
      const SizedBox(height: 12),
      const Card(child: ListTile(
        leading: Icon(Icons.science_outlined, color: Colors.amber),
        title: Text('SIMULATION ONLY — LIVE AI NOT CONNECTED'),
        subtitle: Text('Generated examples do not inspect camera frames. '
          'No real-time detection, face identification or drone commands are active.'),
      )),
      if (_error != null) Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(_error!, style: const TextStyle(color: Colors.orangeAccent))),
      const SizedBox(height: 12),
      Wrap(spacing: 10, runSpacing: 10, children: [
        _metric('EVENTS', '${_findings.length}', Icons.event_note),
        _metric('PENDING', '$pending', Icons.pending_actions),
        _metric('VERIFIED', '$verified', Icons.verified_outlined),
      ]),
      const SizedBox(height: 12),
      Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('DETECTION SETTINGS', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text('Minimum confidence: ${(_threshold * 100).round()}%'),
          Slider(value: _threshold, min: 0.4, max: 0.95, divisions: 11,
            label: '${(_threshold * 100).round()}%',
            onChanged: (value) => setState(() => _threshold = value)),
          Wrap(spacing: 10, children: DetectionCategory.values.map((category) =>
            FilterChip(label: Text(category.name.toUpperCase()),
              selected: _enabled.contains(category),
              onSelected: (selected) => setState(() {
                if (selected) { _enabled.add(category); }
                else { _enabled.remove(category); }
              }))).toList()),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _mode,
            decoration: const InputDecoration(labelText: 'Processing preset'),
            items: const [
              DropdownMenuItem(value: 'eco', child: Text('Eco')),
              DropdownMenuItem(value: 'balanced', child: Text('Balanced')),
              DropdownMenuItem(value: 'performance', child: Text('Performance')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _mode = value);
            }),
          const SizedBox(height: 12),
          TextField(controller: _source,
            decoration: const InputDecoration(
              labelText: 'Simulated source name', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          FilledButton.icon(onPressed: _busy ? null : _simulate,
            icon: const Icon(Icons.play_circle_outline),
            label: const Text('GENERATE SIMULATED DETECTIONS')),
        ],
      ))),
      const SizedBox(height: 14),
      Row(children: [
        const Expanded(child: Text('AI EVENT CENTER',
          style: TextStyle(fontWeight: FontWeight.bold))),
        DropdownButton<ReviewStatus?>(
          value: _filter,
          hint: const Text('All events'),
          items: [
            const DropdownMenuItem<ReviewStatus?>(value: null, child: Text('All events')),
            ...ReviewStatus.values.map((status) =>
              DropdownMenuItem<ReviewStatus?>(
                value: status, child: Text(status.name.toUpperCase()))),
          ],
          onChanged: (value) => setState(() => _filter = value)),
      ]),
      if (visible.isEmpty) const Card(child: ListTile(
        title: Text('No matching events'),
        subtitle: Text('Generate a simulated event to test operator review.'))),
      ...visible.map((finding) => Card(child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.center_focus_strong, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(finding.category.name.toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.bold))),
            Text('${(finding.confidence * 100).round()}%'),
          ]),
          const SizedBox(height: 6),
          Text('${finding.source} • ${finding.timestamp.toLocal()}'),
          Text('SIMULATED • ${finding.status.name.toUpperCase()}',
            style: const TextStyle(color: Colors.amber, fontSize: 12)),
          if (finding.missionId.isNotEmpty)
            Text('Mission reference: ${finding.missionId}'),
          if (finding.notes.isNotEmpty) Text('Notes: ${finding.notes}'),
          const SizedBox(height: 10),
          if (finding.status == ReviewStatus.pending) ...[
            TextField(controller: _mission,
              decoration: const InputDecoration(
                labelText: 'Mission ID (manual reference)',
                border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: _notes,
              decoration: const InputDecoration(
                labelText: 'Operator notes', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              FilledButton.icon(
                onPressed: () => _review(finding, ReviewStatus.verified),
                icon: const Icon(Icons.check),
                label: const Text('VERIFY')),
              OutlinedButton.icon(
                onPressed: () => _review(finding, ReviewStatus.dismissed),
                icon: const Icon(Icons.close),
                label: const Text('DISMISS')),
            ]),
          ],
        ]),
      ))),
      const SizedBox(height: 12),
      const Text('Stored locally. Manual mission references do not modify '
        'mission plans. Live frame inference and bounding-box overlays require '
        'a separately validated cross-platform frame adapter and AI model.',
        style: TextStyle(color: Colors.white60, fontSize: 12)),
    ]);
  }

  Widget _metric(String label, String value, IconData icon) => SizedBox(
    width: 160, child: Card(child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: Colors.lightBlueAccent),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 11)),
      ]),
    )));
}
