import 'dart:io';
import 'package:camera/camera.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:video_player/video_player.dart';
import '../../ai/models/ai_finding.dart';
import '../../ai/services/native_ai_engine.dart';
import '../../ai/services/yolox_onnx_engine.dart';
import '../../ai/services/plate_ocr_onnx_engine.dart';
import '../../ai/services/vehicle_visual_search.dart';
import '../../ai/services/plate_ocr_validation.dart';
import '../../ai/services/anonymous_object_tracker.dart';
import '../../ai/services/rescue_snapshot_assessment.dart';
import '../../ai/services/camera_frame_converter.dart';

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
  bool _liveAiActive = false;
  bool _liveFrameBusy = false;
  DateTime _lastLiveInference = DateTime.fromMillisecondsSinceEpoch(0);
  int _liveInferenceCount = 0;
  Size? _liveImageSize;
  String? _cameraError;
  NativeAiStatus _ai = const NativeAiStatus(false, 'MODEL NOT LOADED');
  final _engine = YoloxOnnxEngine();
  final _plateOcr = PlateOcrOnnxEngine();
  final _objectTracker = AnonymousObjectTracker();
  List<TrackedDetection> _trackedDetections = const [];
  bool _ocrReady = false;
  bool _ocrBusy = false;
  String? _ocrStatus;
  List<PlateOcrCandidate> _plateCandidates = const [];
  List<NativeDetection> _detections = const [];
  RescueSnapshotAssessment? _rescueAssessment;
  final Map<int, RescueOperatorAssessment> _operatorAssessments = {};
  Uint8List? _currentImage;
  int _frameSequence = 0;
  String? _currentFrameId;
  final List<VehicleVisualCandidate> _vehicleCorpus = [];
  List<({String frameId, double score})> _vehicleMatches = const [];
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

  Future<bool> _loadAi() async {
    if (_ai.ready) return true;
    if (_modelLoading) return false;
    if (mounted) setState(() => _modelLoading = true);
    final status = await _engine.initialize();
    if (mounted) setState(() { _ai = status; _modelLoading = false; });
    return status.ready;
  }

  int _deviceRotation(DeviceOrientation orientation) => switch (orientation) {
    DeviceOrientation.portraitUp => 0,
    DeviceOrientation.landscapeLeft => 90,
    DeviceOrientation.portraitDown => 180,
    DeviceOrientation.landscapeRight => 270,
  };

  Future<void> _startLiveAi(CameraController camera, {bool modelReady = false}) async {
    final ready = modelReady || await _loadAi();
    if (!mounted || !ready || !identical(camera, _camera) ||
        !camera.value.isInitialized) {
      return;
    }
    try {
      await camera.startImageStream((frame) => _onLiveFrame(camera, frame));
      if (mounted && identical(camera, _camera)) {
        setState(() { _liveAiActive = true; _cameraError = null; });
      }
    } catch (error) {
      if (mounted) setState(() {
        _liveAiActive = false;
        _cameraError = 'Camera preview is live, but live AI stream could not start: $error';
      });
    }
  }

  Future<void> _loadAiAndStartLive() async {
    final camera = _camera;
    final ready = await _loadAi();
    if (!ready || camera == null || !camera.value.isInitialized ||
        camera.value.isStreamingImages) {
      return;
    }
    await _startLiveAi(camera, modelReady: true);
  }

  Future<void> _onLiveFrame(CameraController camera, CameraImage frame) async {
    final now = DateTime.now();
    if (!mounted || !identical(camera, _camera) || _liveFrameBusy ||
        now.difference(_lastLiveInference) < const Duration(milliseconds: 450)) {
      return;
    }
    _liveFrameBusy = true;
    _lastLiveInference = now;
    try {
      var rgb = await cameraFrameToRgb(frame);
      final sensor = camera.description.sensorOrientation;
      final device = _deviceRotation(camera.value.deviceOrientation);
      final rotation = camera.description.lensDirection == CameraLensDirection.front
          ? (sensor + device) % 360
          : (sensor - device + 360) % 360;
      if (rotation != 0) rgb = img.copyRotate(rgb, angle: rotation);
      _liveImageSize = Size(rgb.width.toDouble(), rgb.height.toDouble());
      final detections = await _engine.detectImage(rgb);
      final tracks = _objectTracker.update(detections);
      _liveInferenceCount++;
      Uint8List? frameJpeg;
      final vehicles = <NativeDetection>[];
      for (var i = 0; i < detections.length; i++) {
        if (detections[i].category == DetectionCategory.vehicle) vehicles.add(detections[i]);
      }
      // Keep a small, local appearance-search sample without JPEG work on
      // frames that have no vehicle or on every inference tick.
      if (vehicles.isNotEmpty) {
        frameJpeg = Uint8List.fromList(img.encodeJpg(rgb, quality: 72));
      }
      final frameId = 'live-${++_frameSequence}';
      final candidates = <VehicleVisualCandidate>[];
      if (frameJpeg != null && _liveInferenceCount % 8 == 0) {
        for (var i = 0; i < detections.length; i++) {
          final detection = detections[i];
          if (detection.category != DetectionCategory.vehicle) continue;
          candidates.add(VehicleVisualCandidate('$frameId-vehicle-$i',
            VehicleVisualSearch.describeJpeg(frameJpeg,
              x: detection.x, y: detection.y,
              width: detection.width, height: detection.height)));
        }
      }
      final assessment = RescueSnapshotAssessment.fromDetections(detections);
      if (!mounted || !identical(camera, _camera)) return;
      setState(() {
        _detections = detections;
        _trackedDetections = tracks;
        _rescueAssessment = assessment;
        _operatorAssessments.clear();
        _currentImage = vehicles.isEmpty ? null : frameJpeg;
        _currentFrameId = vehicles.isEmpty ? null : frameId;
        _vehicleMatches = const [];
        _vehicleCorpus.addAll(candidates);
        if (_vehicleCorpus.length > 500) {
          _vehicleCorpus.removeRange(0, _vehicleCorpus.length - 500);
        }
      });
    } catch (error) {
      if (mounted && identical(camera, _camera)) {
        setState(() => _cameraError = 'Offline live inference failed: $error');
      }
    } finally {
      _liveFrameBusy = false;
    }
  }

  Future<void> _startCamera({bool switchLens = false}) async {
    if (!Platform.isAndroid) {
      setState(() => _cameraError = 'Local camera test is currently supported on Android only.');
      return;
    }
    if (_connecting) return;
    if (switchLens) {
      _objectTracker.reset();
      _trackedDetections = const [];
    }
    setState(() { _connecting = true; _cameraError = null; });
    try {
      _available = await availableCameras();
      if (_available.isEmpty) throw StateError('No camera available');
      if (switchLens) _cameraIndex = (_cameraIndex + 1) % _available.length;
      await _camera?.dispose();
      _camera = null;
      final next = CameraController(_available[_cameraIndex], ResolutionPreset.medium,
          enableAudio: false, imageFormatGroup: ImageFormatGroup.yuv420, fps: 15);
      await next.initialize();
      if (!mounted) { await next.dispose(); return; }
      setState(() => _camera = next);
      await _startLiveAi(next);
    } catch (error) {
      if (mounted) setState(() => _cameraError = 'Camera unavailable or permission denied: $error');
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _stopCamera() async {
    final previous = _camera;
    setState(() => _camera = null);
    _liveAiActive = false;
    _liveFrameBusy = false;
    _detections = const [];
    _currentImage = null;
    _rescueAssessment = null;
    _objectTracker.reset();
    setState(() => _trackedDetections = const []);
    if (previous?.value.isStreamingImages == true) {
      try { await previous!.stopImageStream(); } catch (_) {}
    }
    await previous?.dispose();
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
      await _analyzeBytes(bytes);
    } catch (error) {
      if (mounted) setState(() => _cameraError = 'Offline model inference failed: $error');
    } finally {
      if (mounted) setState(() => _analysisBusy = false);
    }
  }

  Future<void> _analyzeBytes(Uint8List bytes) async {
    setState(() { _analysisBusy = true; _cameraError = null; });
    try {
      final detections = await _engine.detectJpeg(bytes);
      final rescueAssessment = RescueSnapshotAssessment.fromDetections(detections);
      _objectTracker.reset();
      final tracks = <TrackedDetection>[];
      final frameId = 'frame-${++_frameSequence}';
      final newCandidates = <VehicleVisualCandidate>[];
      for (var i = 0; i < detections.length; i++) {
        final detection = detections[i];
        if (detection.category != DetectionCategory.vehicle) continue;
        newCandidates.add(VehicleVisualCandidate('$frameId-vehicle-$i',
          VehicleVisualSearch.describeJpeg(bytes, x: detection.x, y: detection.y,
            width: detection.width, height: detection.height)));
      }
      if (mounted) {
        setState(() {
          _currentImage = bytes;
          _currentFrameId = frameId;
          _detections = detections;
          _rescueAssessment = rescueAssessment;
          _operatorAssessments.clear();
          _trackedDetections = tracks;
          _vehicleMatches = const [];
          _plateCandidates = const [];
          _ocrStatus = null;
          _vehicleCorpus.addAll(newCandidates);
          if (_vehicleCorpus.length > 500) {
            _vehicleCorpus.removeRange(0, _vehicleCorpus.length - 500);
          }
        });
      }
    } finally {
      if (mounted) setState(() => _analysisBusy = false);
    }
  }

  String? _trackIdFor(NativeDetection detection) {
    for (final track in _trackedDetections) {
      if (identical(track.detection, detection)) return track.trackId.toString();
    }
    return null;
  }

  void _searchSimilarVehicles() {
    final bytes = _currentImage;
    if (bytes == null || _currentFrameId == null) return;
    try {
      final query = <List<double>>[];
      for (final detection in _detections) {
        if (detection.category == DetectionCategory.vehicle) {
          query.add(VehicleVisualSearch.describeJpeg(bytes, x: detection.x,
            y: detection.y, width: detection.width, height: detection.height));
        }
      }
      if (query.isEmpty) {
        setState(() => _cameraError = 'No vehicle crop in the selected image.');
        return;
      }
      final candidates = _vehicleCorpus.where((item) =>
        !item.localFrameId.startsWith('$_currentFrameId-')).toList();
      final ranked = <({String frameId, double score})>[];
      for (final vector in query) {
        ranked.addAll(VehicleVisualSearch.rank(vector, candidates, limit: 20));
      }
      final bestByFrame = <String, double>{};
      for (final match in ranked) {
        if (match.score < 0) continue;
        final previous = bestByFrame[match.frameId];
        if (previous == null || match.score > previous) bestByFrame[match.frameId] = match.score;
      }
      final results = bestByFrame.entries.map((entry) =>
        (frameId: entry.key, score: entry.value)).toList()
        ..sort((a, b) => b.score.compareTo(a.score));
      setState(() {
        _vehicleMatches = results.take(10).toList();
        _cameraError = null;
      });
    } catch (error) {
      setState(() => _cameraError = 'Vehicle appearance search failed: $error');
    }
  }

  Future<void> _runPlateOcr() async {
    final bytes = _currentImage;
    if (bytes == null || _ocrBusy) return;
    setState(() { _ocrBusy = true; _ocrStatus = 'LOADING LOCAL OCR'; });
    try {
      if (!_ocrReady) {
        final status = await _plateOcr.initialize();
        if (!status.ready) throw StateError(status.message);
        _ocrReady = true;
      }
      final candidates = await _plateOcr.readVehicleText(bytes, _detections);
      if (mounted) {
        setState(() {
          _plateCandidates = candidates;
          _ocrStatus = candidates.isEmpty ? 'NO PLATE-SHAPED TEXT FOUND' : null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _ocrStatus = 'LOCAL OCR FAILED: $error');
    } finally {
      if (mounted) setState(() => _ocrBusy = false);
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
    _plateOcr.dispose();
    super.dispose();
  }

  Widget _viewport(int index) {
    final local = index == 0;
    final player = local ? null : _players[index - 1];
    final active = local ? (_camera?.value.isInitialized ?? false) :
        (player?.value.isInitialized ?? false);
    Widget image = const Center(child: Icon(Icons.videocam_off_outlined, color: Color(0xFF5E7966), size: 42));
    if (local && active) {
      image = Stack(fit: StackFit.expand, children: [
        CameraPreview(_camera!),
        if (_liveAiActive && _liveImageSize != null)
          Positioned.fill(child: CustomPaint(painter: _LiveDetectionPainter(
            detections: _detections,
            imageSize: _liveImageSize!,
            mirrored: _camera!.description.lensDirection == CameraLensDirection.front,
          ))),
        if (_modelLoading)
          const Positioned(left: 8, top: 8, child: _LiveAiBadge(label: 'LOADING OFFLINE AI'))
        else if (_liveAiActive)
          const Positioned(left: 8, top: 8, child: _LiveAiBadge(label: 'OFFLINE AI • LIVE')),
      ]);
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
            if (active) Chip(
              avatar: Icon(_liveAiActive ? Icons.radar : Icons.memory,
                  size: 16, color: _liveAiActive ? _accent : _amber),
              label: Text(_liveAiActive ? 'AUTO LIVE AI' :
                  _modelLoading ? 'LOADING AI' : 'AI NOT READY'),
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

  Widget _rescueReviewCard(RescueSnapshotAssessment assessment) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFF101C16),
      border: Border.all(color: _line),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('SAR PERSON CHECK',
          style: TextStyle(color: _accent, fontWeight: FontWeight.bold)),
      const SizedBox(height: 5),
      Text('People detected in this snapshot: ${assessment.peopleCount}',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      if (assessment.possibleHorizontalPostureCount > 0)
        Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text('Visual cue: ${assessment.possibleHorizontalPostureCount} person box(es) have a wide/horizontal shape. Verify posture and condition in the image; this is not an injury diagnosis.',
              style: const TextStyle(color: _amber, fontSize: 12)),
        )
      else
        const Padding(
          padding: EdgeInsets.only(top: 5),
          child: Text('No wide/horizontal posture cue. The model cannot determine injury or whether someone is asking for help.',
              style: TextStyle(color: Colors.white70, fontSize: 12)),
        ),
      for (final person in assessment.people) ...[
        const SizedBox(height: 6),
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(child: Text(
            'Person ${person.frameIndex} • ${(person.confidence * 100).toStringAsFixed(0)}%${person.possibleHorizontalPosture ? ' • posture cue' : ''}',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          )),
          const SizedBox(width: 8),
          Flexible(child: DropdownButton<RescueOperatorAssessment>(
            value: _operatorAssessments[person.frameIndex] ?? RescueOperatorAssessment.unreviewed,
            isExpanded: true,
            dropdownColor: _surface,
            style: const TextStyle(color: Colors.white, fontSize: 11),
            items: [
              for (final option in RescueOperatorAssessment.values)
                DropdownMenuItem(value: option,
                  child: Text(option.label, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() => _operatorAssessments[person.frameIndex] = value);
            },
          )),
        ]),
      ],
      const SizedBox(height: 5),
      const Text('Person numbers are temporary for this image. Injury/help selections are operator assessments and are not saved as diagnoses.',
          style: TextStyle(color: Colors.white54, fontSize: 10)),
    ]),
  );

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
        const SizedBox(height: 4),
        const Text('PHONE → WINDOWS: no direct camera link is configured. Windows feeds require an external HTTPS streaming gateway.',
            style: TextStyle(color: _amber, fontSize: 11)),
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
              onPressed: _modelLoading ? null : _loadAiAndStartLive,
              icon: _modelLoading
                  ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.memory),
              label: Text(_modelLoading ? 'LOADING LOCAL MODEL' : 'LOAD OFFLINE YOLOX MODEL'),
            ),
            Text(_liveAiActive
                ? 'Live camera frames are analyzed locally; boxes update automatically without taking a snapshot.'
                : 'Connect the Android camera to load YOLOX and start offline live analysis automatically.',
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: _ai.ready && !_analysisBusy &&
                  _camera?.value.isInitialized != true ? _analyzeLocalImage : null,
              icon: const Icon(Icons.image_search_outlined),
              label: const Text('PICK IMAGE AND ANALYZE OFFLINE'),
            ),
            if (_rescueAssessment != null) ...[
              const SizedBox(height: 12),
              _rescueReviewCard(_rescueAssessment!),
            ],
            if (_detections.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('LOCAL DETECTIONS: ${_detections.length}',
                  style: const TextStyle(color: _accent, fontWeight: FontWeight.bold)),
              if (_trackedDetections.isNotEmpty)
                const Text('TEMPORARY TRACK IDs apply only to vehicles, animals and objects across camera snapshots.',
                    style: TextStyle(color: Colors.white70, fontSize: 11)),
              const SizedBox(height: 4),
              for (final detection in _detections.take(12))
                Text('${_trackIdFor(detection) == null ? '' : 'T${_trackIdFor(detection)} • '}${detection.label} • ${(detection.confidence * 100).toStringAsFixed(1)}% • ${detection.category.name}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
              if (_detections.any((d) => d.category == DetectionCategory.vehicle)) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _vehicleCorpus.length > 1 ? _searchSimilarVehicles : null,
                  icon: const Icon(Icons.manage_search),
                  label: const Text('SEARCH SIMILAR VEHICLES IN THIS SESSION'),
                ),
                const Text('Ranks visual candidates from local session frames. Similarity is not vehicle identity.',
                    style: TextStyle(color: Colors.white70, fontSize: 11)),
                for (final match in _vehicleMatches.take(5))
                  Text('${match.frameId} • visual similarity ${(match.score * 100).toStringAsFixed(1)}% • operator review',
                      style: const TextStyle(color: Colors.white70, fontSize: 12)),
                OutlinedButton.icon(
                  onPressed: _ocrBusy || _analysisBusy ? null : _runPlateOcr,
                  icon: _ocrBusy
                      ? const SizedBox(width: 15, height: 15,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.document_scanner_outlined),
                  label: Text(_ocrBusy ? 'READING LOCAL PLATE TEXT' : 'READ PLATE TEXT OFFLINE'),
                ),
                if (_ocrStatus != null) Text(_ocrStatus!,
                  style: const TextStyle(color: _amber, fontSize: 11)),
                for (final candidate in _plateCandidates)
                  Text('${candidate.normalized} • ${(candidate.confidence * 100).toStringAsFixed(1)}% • VERIFY VISUALLY',
                    style: const TextStyle(color: _amber, fontSize: 12)),
                if (_plateCandidates.isNotEmpty)
                  const Text('Suggestions are temporary and unconfirmed. No owner or registry lookup is performed.',
                    style: TextStyle(color: Colors.white70, fontSize: 11)),
              ],
            ] else if (!_analysisBusy && _ai.ready) ...[
              const SizedBox(height: 5),
              const Text('Waiting for live camera detections. Connect the Android camera to begin.',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
            ],
            const SizedBox(height: 5),
            const Text('The packaged YOLOX-Nano model analyzes Android phone-camera frames locally and detects COCO-80 classes. External streams are preview-only.',
                style: TextStyle(color: Colors.white70, fontSize: 12)),
          ]))),
      ]);
    },
  ));
}

class _LiveAiBadge extends StatelessWidget {
  final String label;
  const _LiveAiBadge({required this.label});

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(color: const Color(0xC6000000),
      border: Border.all(color: _accent), borderRadius: BorderRadius.circular(4)),
    child: Padding(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      child: Text(label, style: const TextStyle(color: _accent,
        fontWeight: FontWeight.bold, fontSize: 9))),
  );
}

class _LiveDetectionPainter extends CustomPainter {
  final List<NativeDetection> detections;
  final Size imageSize;
  final bool mirrored;

  _LiveDetectionPainter({required this.detections, required this.imageSize,
    required this.mirrored});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || imageSize.isEmpty) return;
    final fitted = applyBoxFit(BoxFit.cover, imageSize, size);
    final destination = Alignment.center.inscribe(fitted.destination, Offset.zero & size);
    final source = Alignment.center.inscribe(fitted.source, Offset.zero & imageSize);
    final stroke = Paint()..style = PaintingStyle.stroke..strokeWidth = 2;
    for (final detection in detections) {
      if (!detection.valid) continue;
      stroke.color = detection.category == DetectionCategory.person
          ? const Color(0xFF9FE870)
          : detection.category == DetectionCategory.vehicle
              ? const Color(0xFFFFC857)
              : Colors.cyanAccent;
      final normalizedX = mirrored ? 1 - detection.x - detection.width : detection.x;
      final left = (normalizedX * imageSize.width - source.left) / source.width;
      final top = (detection.y * imageSize.height - source.top) / source.height;
      final width = detection.width * imageSize.width / source.width;
      final height = detection.height * imageSize.height / source.height;
      final rect = Rect.fromLTWH(destination.left + left * destination.width,
        destination.top + top * destination.height,
        width * destination.width, height * destination.height);
      if (!rect.overlaps(destination)) continue;
      canvas.drawRect(rect, stroke);
      final label = '${detection.label.toUpperCase()} ${(detection.confidence * 100).round()}%';
      final text = TextPainter(text: TextSpan(text: label, style: const TextStyle(
        color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold,
        backgroundColor: Colors.black87)), textDirection: TextDirection.ltr)
        ..layout(maxWidth: size.width);
      final labelY = rect.top - text.height < destination.top
          ? rect.top : rect.top - text.height;
      text.paint(canvas, Offset(rect.left, labelY));
    }
  }

  @override
  bool shouldRepaint(covariant _LiveDetectionPainter oldDelegate) =>
      oldDelegate.detections != detections || oldDelegate.imageSize != imageSize ||
      oldDelegate.mirrored != mirrored;
}
