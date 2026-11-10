import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/ai_finding.dart';

class LiveBox {
  final DetectionCategory category;
  final double confidence;
  final Rect bounds;
  const LiveBox(this.category, this.confidence, this.bounds);
}

/// HTTPS JPEG snapshot polling + HTTPS inference service adapter.
/// Inference server must accept image/jpeg POST and return JSON:
/// {"detections":[{"category":"person","confidence":0.9,
/// "box":[0.1,0.2,0.3,0.4]}]}; box is normalized x,y,width,height.
class LiveInferenceClient {
  final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 8);

  Future<Uint8List> snapshot(Uri uri) async {
    final request = await _client.getUrl(uri);
    request.headers.set(HttpHeaders.acceptHeader, 'image/jpeg');
    final response = await request.close().timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) throw const FormatException('Camera returned non-200');
    final bytes = <int>[];
    await for (final chunk in response) {
      bytes.addAll(chunk);
      if (bytes.length > 4000000) { throw const FormatException('Frame exceeds 4MB'); }
    }
    if (bytes.length < 4 || bytes[0] != 0xff || bytes[1] != 0xd8) {
      throw const FormatException('Camera did not return JPEG');
    }
    return Uint8List.fromList(bytes);
  }

  Future<List<LiveBox>> detect(Uri endpoint, Uint8List jpeg) async {
    final request = await _client.postUrl(endpoint);
    request.headers.contentType = ContentType('image', 'jpeg');
    request.add(jpeg);
    final response = await request.close().timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) throw const FormatException('Inference server error');
    final raw = await utf8.decoder.bind(response).join();
    if (raw.length > 1000000) throw const FormatException('Oversized inference response');
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final entries = data['detections'] as List<dynamic>? ?? [];
    return entries.take(100).map((entry) {
      final obj = Map<String, dynamic>.from(entry as Map);
      final category = DetectionCategory.values.byName(obj['category'] as String);
      final confidence = (obj['confidence'] as num).toDouble();
      final coords = (obj['box'] as List<dynamic>).cast<num>();
      if (coords.length != 4 || !confidence.isFinite || confidence < 0 || confidence > 1) {
        throw const FormatException('Invalid inference result');
      }
      final x = coords[0].toDouble();
      final y = coords[1].toDouble();
      final w = coords[2].toDouble();
      final h = coords[3].toDouble();
      if (![x,y,w,h].every((v) => v.isFinite && v >= 0 && v <= 1) ||
          x + w > 1.001 || y + h > 1.001) {
        throw const FormatException('Invalid bounding box');
      }
      return LiveBox(category, confidence, Rect.fromLTWH(x, y, w, h));
    }).toList();
  }

  void close() => _client.close(force: true);
}

class LiveAiPanel extends StatefulWidget {
  final AiAnalysisSettings settings;
  final Future<void> Function(List<AiFinding>) onDetections;
  const LiveAiPanel({super.key, required this.settings, required this.onDetections});
  @override
  State<LiveAiPanel> createState() => _LiveAiPanelState();
}

class _LiveAiPanelState extends State<LiveAiPanel> {
  final _camera = TextEditingController();
  final _endpoint = TextEditingController();
  final _client = LiveInferenceClient();
  Timer? _timer;
  Uint8List? _frame;
  List<LiveBox> _boxes = [];
  String? _error;
  bool _active = false;
  bool _processing = false;
  int _ticks = 0;

  Uri? _validated(String raw) {
    final uri = Uri.tryParse(raw.trim());
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty &&
      uri.userInfo.isEmpty ? uri : null;
  }

  void _start() {
    if (_validated(_camera.text) == null || _validated(_endpoint.text) == null) {
      setState(() => _error = 'Both URLs must be HTTPS without embedded credentials.');
      return;
    }
    setState(() { _active = true; _error = null; });
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _tick());
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    setState(() => _active = false);
  }

  Future<void> _tick() async {
    if (!_active || _processing) return;
    _processing = true;
    try {
      final frame = await _client.snapshot(_validated(_camera.text)!);
      final detections = await _client.detect(_validated(_endpoint.text)!, frame);
      if (!mounted || !_active) return;
      final accepted = detections.where((d) =>
        widget.settings.enabled.contains(d.category) &&
        d.confidence >= widget.settings.threshold).toList();
      setState(() { _frame = frame; _boxes = accepted; _error = null; });
      final now = DateTime.now().toUtc();
      _ticks++;
      if (accepted.isNotEmpty) {
        await widget.onDetections(accepted.map((d) => AiFinding(
          id: '${now.microsecondsSinceEpoch}-$_ticks-${accepted.indexOf(d)}',
          source: _camera.text.trim(), category: d.category,
          confidence: d.confidence, timestamp: now)).toList());
      }
    } catch (e) {
      if (mounted && _active) {
        setState(() {
          _error = 'Live inference unavailable: $e';
          _boxes = [];
        });
      }
    } finally {
      _processing = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _client.close();
    _camera.dispose();
    _endpoint.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Card(child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('LIVE AI — EXTERNAL MODEL', style: TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      const Text('Requires an authorized HTTPS JPEG snapshot camera and a running '
        'HTTPS AI inference service. The app does not include or host an AI model. '
        'Images are sent to the configured service only while LIVE is enabled.'),
      const SizedBox(height: 10),
      TextField(controller: _camera, enabled: !_active,
        decoration: const InputDecoration(labelText: 'Camera JPEG snapshot HTTPS URL',
          border: OutlineInputBorder())),
      const SizedBox(height: 8),
      TextField(controller: _endpoint, enabled: !_active,
        decoration: const InputDecoration(labelText: 'AI inference HTTPS endpoint',
          border: OutlineInputBorder())),
      const SizedBox(height: 10),
      FilledButton.icon(
        onPressed: _active ? _stop : _start,
        icon: Icon(_active ? Icons.stop : Icons.play_arrow),
        label: Text(_active ? 'STOP LIVE ANALYSIS' : 'START LIVE ANALYSIS')),
      if (_error != null) Padding(padding: const EdgeInsets.only(top: 8),
        child: Text(_error!, style: const TextStyle(color: Colors.orangeAccent))),
      const SizedBox(height: 12),
      if (_frame != null) AspectRatio(aspectRatio: 16 / 9, child: LayoutBuilder(
        builder: (context, constraints) => Stack(fit: StackFit.expand, children: [
          Image.memory(_frame!, fit: BoxFit.fill, gaplessPlayback: true),
          ..._boxes.map((box) => Positioned(
            left: box.bounds.left * constraints.maxWidth,
            top: box.bounds.top * constraints.maxHeight,
            width: box.bounds.width * constraints.maxWidth,
            height: box.bounds.height * constraints.maxHeight,
            child: Container(decoration: BoxDecoration(border: Border.all(
              color: Colors.lightGreenAccent, width: 2)),
              alignment: Alignment.topLeft,
              child: Text('${box.category.name} ${(box.confidence * 100).round()}%',
                style: const TextStyle(color: Colors.white, backgroundColor: Colors.black87,
                  fontSize: 11))),
          )),
        ]),
      )),
      const Text('Approx. one JPEG frame every 3 seconds; not full-motion video. '
        'Bounding boxes assume image-aligned normalized coordinates. '
        'Only authorized, trusted camera and inference servers should be used.',
        style: TextStyle(fontSize: 11, color: Colors.white60)),
    ]),
  ));
}
