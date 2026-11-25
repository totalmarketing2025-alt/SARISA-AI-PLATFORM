import 'dart:io';
import 'package:camera/camera.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../ai/services/native_ai_engine.dart';
import '../../ai/services/yolox_onnx_engine.dart';

const _bg = Color(0xFF09120F);
const _surface = Color(0xFF15251C);
const _line = Color(0xFF385440);
const _accent = Color(0xFFB9D88D);
const _amber = Color(0xFFE3B36A);

/// Four independent viewports. The first uses the local Android camera.
/// Camera permission is requested by the camera plugin at connection time.
class TacticalCameraWall extends StatefulWidget {
  const TacticalCameraWall({super.key});
  @override
  State<TacticalCameraWall> createState() => _TacticalCameraWallState();
}

class _TacticalCameraWallState extends State<TacticalCameraWall> {
  CameraController? _camera;
  List<CameraDescription> _available = [];
  int _cameraIndex = 0;
  bool _connecting = false;
  String? _cameraError;
  NativeAiStatus _ai = const NativeAiStatus(false, 'MODEL NOT LOADED');
  final _engine = YoloxOnnxEngine();
  List<NativeDetection> _detections = const [];
  bool _modelLoading = false;
  bool _analysisBusy = false;
  final _urls = List.generate(3, (_) => TextEditingController());
  final _players = <int, VideoPlayerController>{};
  final _errors = <int, String>{};
  int _focus = -1;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _loadAi() async {
    if (_ai.ready || _modelLoading) return;
    setState(() => _modelLoading = true);
    final status = await _engine.initialize();
    if (mounted) setState(() { _ai = status; _modelLoading = false; });
  }

  Future<void> _startCamera({bool switchLens = false}) async {
    if (!Platform.isAndroid) {
      setState(() => _cameraError = 'Local camera test is currently supported on Android only.');
      return;
    }
    if (_connecting) return;
    setState(() { _connecting = true; _cameraError = null; });
    try {
      _available = await availableCameras();
      if (_available.isEmpty) throw StateError('No camera available');
      if (switchLens) _cameraIndex = (_cameraIndex + 1) % _available.length;
      await _camera?.dispose();
      _camera = null;
      final next = CameraController(_available[_cameraIndex], ResolutionPreset.medium,
          enableAudio: false, imageFormatGroup: ImageFormatGroup.jpeg);
      await next.initialize();
      if (!mounted) { await next.dispose(); return; }
      setState(() => _camera = next);
    } catch (error) {
      if (mounted) setState(() => _cameraError = 'Camera unavailable or permission denied: $error');
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _stopCamera() async {
    final previous = _camera;
    setState(() => _camera = null);
    await previous?.dispose();
  }

  Future<void> _analyzeSnapshot() async {
    final camera = _camera;
    if (camera == null || !camera.value.isInitialized || !_ai.ready || _analysisBusy) return;
    setState(() { _analysisBusy = true; _cameraError = null; });
    try {
      final photo = await camera.takePicture();
      final detections = await _engine.detectJpeg(await photo.readAsBytes());
      if (mounted) setState(() => _detections = detections);
    } catch (error) {
      if (mounted) setState(() => _cameraError = 'Offline model inference failed: $error');
    } finally {
      if (mounted) setState(() => _analysisBusy = false);
    }
  }

  Future<void> _analyzeLocalImage() async {
    if (!_ai.ready || _analysisBusy) return;
    try {
      final selection = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (selection == null || selection.files.isEmpty) return;
      final file = selection.files.single;
      final bytes = file.bytes ?? (file.path == null ? null : await File(file.path!).readAsBytes());
      if (bytes == null) throw StateError('Could not read the selected image.');
      setState(() { _analysisBusy = true; _cameraError = null; });
      final detections = await _engine.detectJpeg(bytes);
      if (mounted) setState(() => _detections = detections);
    } catch (error) {
      if (mounted) setState(() => _cameraError = 'Offline model inference failed: $error');
    } finally {
      if (mounted) setState(() => _analysisBusy = false);
    }
  }

  Future<void> _connect(int slot) async {
    final url = Uri.tryParse(_urls[slot].text.trim());
    if (url == null || url.scheme != 'https' || url.host.isEmpty) {
      setState(() => _errors[slot] = 'Use a valid HTTPS media URL');
      return;
    }
    final old = _players.remove(slot);
    await old?.dispose();
    VideoPlayerController? player;
    try {
      player = VideoPlayerController.networkUrl(url);
      await player.initialize();
      await player.play();
      if (!mounted) { await player.dispose(); return; }
      setState(() { _players[slot] = player!; _errors.remove(slot); });
    } catch (_) {
      await player?.dispose();
      if (mounted) setState(() => _errors[slot] = 'Unsupported or unavailable stream');
    }
  }

  Future<void> _disconnect(int slot) async {
    final player = _players.remove(slot);
    setState(() {});
    await player?.dispose();
  }

  @override
  void dispose() {
    _camera?.dispose();
    for (final p in _players.values) { p.dispose(); }
    for (final c in _urls) { c.dispose(); }
    _engine.dispose();
    super.dispose();
  }

  Widget _viewport(int index) {
    final local = index == 0;
    final player = local ? null : _players[index - 1];
    final active = local ? (_camera?.value.isInitialized ?? false) :
        (player?.value.isInitialized ?? false);
    Widget image = const Center(child: Icon(Icons.videocam_off_outlined, color: Color(0xFF5E7966), size: 42));
    if (local && active) {
      image = CameraPreview(_camera!);
    } else if (!local && active) {
      image = Center(child: AspectRatio(aspectRatio: player!.value.aspectRatio,
          child: VideoPlayer(player)));
    }
    return Container(
      decoration: BoxDecoration(color: _surface, border: Border.all(color: _line),
          borderRadius: BorderRadius.circular(8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(padding: const EdgeInsets.all(9), child: Row(children: [
          Icon(active ? Icons.circle : Icons.circle_outlined, color: active ? _accent : _amber, size: 11),
          const SizedBox(width: 7),
          Expanded(child: Text(local ? 'CAM 01 / PHONE AI TEST' : 'CAM 0${index + 1} / EXTERNAL',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
          Text(active ? 'LIVE' : 'OFFLINE', style: TextStyle(color: active ? _accent : _amber, fontSize: 10)),
          IconButton(tooltip: 'Expand feed', icon: const Icon(Icons.open_in_full, size: 17),
              onPressed: () => setState(() => _focus = _focus == index ? -1 : index)),
        ])),
        AspectRatio(aspectRatio: 16 / 9, child: ClipRect(child: ColoredBox(color: _bg, child: image))),
        Padding(padding: const EdgeInsets.all(9), child: local ?
          Wrap(spacing: 6, runSpacing: 6, children: [
            OutlinedButton.icon(onPressed: _connecting ? null : () => active ? _stopCamera() : _startCamera(),
                icon: Icon(active ? Icons.stop : Icons.camera_alt, size: 16),
                label: Text(active ? 'STOP CAMERA' : 'CONNECT CAMERA')),
            OutlinedButton.icon(onPressed: _connecting || !active || _available.length < 2 ? null :
                () => _startCamera(switchLens: true),
                icon: const Icon(Icons.flip_camera_android, size: 16), label: const Text('FLIP')),
            FilledButton.tonalIcon(
              onPressed: active && _ai.ready && !_analysisBusy ? _analyzeSnapshot : null,
              icon: _analysisBusy
                  ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.document_scanner_outlined, size: 16),
              label: Text(_analysisBusy ? 'ANALYZING OFFLINE' : 'ANALYZE SNAPSHOT'),
            ),
          ]) :
          Column(children: [
            TextField(controller: _urls[index - 1], style: const TextStyle(fontSize: 12),
              decoration: const InputDecoration(isDense: true, labelText: 'HTTPS media URL',
                  border: OutlineInputBorder())),
            const SizedBox(height: 6),
            Align(alignment: Alignment.centerLeft, child: OutlinedButton.icon(
              onPressed: () => active ? _disconnect(index - 1) : _connect(index - 1),
              icon: Icon(active ? Icons.link_off : Icons.link, size: 16),
              label: Text(active ? 'DISCONNECT' : 'CONNECT'))),
            if (_errors[index - 1] != null) Text(_errors[index - 1]!,
                style: const TextStyle(color: _amber, fontSize: 11)),
          ])),
        if (local && _cameraError != null) Padding(padding: const EdgeInsets.all(8),
            child: Text(_cameraError!, style: const TextStyle(color: _amber, fontSize: 11))),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) => Container(color: _bg, child: LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth > 760;
      final visible = _focus < 0 ? [0, 1, 2, 3] : [_focus];
      return ListView(padding: const EdgeInsets.all(16), children: [
        const Text('TACTICAL VIDEO WALL', style: TextStyle(color: _accent,
            fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
        const SizedBox(height: 6),
        const Text('Four feeds • local Android camera test • operator-authorized HTTPS streams',
            style: TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 12),
        Wrap(spacing: 10, runSpacing: 8, children: [
          Chip(label: Text('CAMERAS: ${(_camera?.value.isInitialized ?? false ? 1 : 0) + _players.length}/4')),
          Chip(label: Text('ON-DEVICE AI: ${_ai.ready ? "READY" : "NOT INSTALLED"}')),
          if (_focus >= 0) TextButton.icon(onPressed: () => setState(() => _focus = -1),
              icon: const Icon(Icons.grid_view), label: const Text('SHOW ALL FOUR')),
        ]),
        const SizedBox(height: 10),
        LayoutBuilder(builder: (context, inner) {
          final cellWidth = wide && _focus < 0 ? (inner.maxWidth - 12) / 2 : inner.maxWidth;
          return Wrap(spacing: 12, runSpacing: 12,
            children: visible.map((i) => SizedBox(width: cellWidth, child: _viewport(i))).toList());
        }),
        const SizedBox(height: 14),
        Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('AI DETECTION CONTROL', style: TextStyle(color: _accent, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(_ai.message, style: const TextStyle(color: _amber)),
            const SizedBox(height: 8),
            if (!_ai.ready) FilledButton.tonalIcon(
              onPressed: _modelLoading ? null : _loadAi,
              icon: _modelLoading
                  ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.memory),
              label: Text(_modelLoading ? 'LOADING LOCAL MODEL' : 'LOAD OFFLINE YOLOX MODEL'),
            ),
            FilledButton.icon(onPressed: _ai.ready && _camera?.value.isInitialized == true && !_analysisBusy
                ? _analyzeSnapshot : null,
                icon: const Icon(Icons.play_arrow), label: const Text('ANALYZE LOCAL SNAPSHOT')),
            if (Platform.isWindows) ...[
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: _ai.ready && !_analysisBusy ? _analyzeLocalImage : null,
                icon: const Icon(Icons.image_search_outlined),
                label: const Text('PICK IMAGE AND ANALYZE OFFLINE'),
              ),
            ],
            if (_detections.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('LOCAL DETECTIONS: ${_detections.length}',
                  style: const TextStyle(color: _accent, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              for (final detection in _detections.take(12))
                Text('${detection.label} • ${(detection.confidence * 100).toStringAsFixed(1)}% • ${detection.category.name}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ] else if (!_analysisBusy && _ai.ready) ...[
              const SizedBox(height: 5),
              const Text('No local detections yet. Capture a snapshot to run the offline model.',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
            ],
            const SizedBox(height: 5),
            const Text('The packaged YOLOX-Nano model analyzes phone-camera snapshots locally. It detects COCO-80 classes only; external streams are preview-only.',
                style: TextStyle(color: Colors.white70, fontSize: 12)),
          ]))),
      ]);
    },
  ));
}
