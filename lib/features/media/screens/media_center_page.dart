import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

/// Phase 10: operator-authorized, view-only video source management.
class MediaCenterPage extends StatefulWidget {
  const MediaCenterPage({super.key});
  @override
  State<MediaCenterPage> createState() => _MediaCenterPageState();
}

class _MediaCenterPageState extends State<MediaCenterPage> {
  final _name = TextEditingController();
  final _url = TextEditingController();
  final List<_MediaSource> _sources = [];
  final Map<String, VideoPlayerController> _players = {};
  final Map<String, String> _errors = {};
  bool _busy = false;

  Future<File> _store() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/sarisa_media_sources.json');
  }

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    try {
      final file = await _store();
      if (!await file.exists()) return;
      final data = jsonDecode(await file.readAsString()) as List<dynamic>;
      if (!mounted) return;
      setState(() {
        _sources.addAll(data.map((e) => _MediaSource.fromJson(e as Map<String, dynamic>)));
      });
    } catch (_) {
      if (mounted) setState(() => _errors['storage'] = 'Saved source list could not be loaded.');
    }
  }

  Future<void> _save() async {
    final file = await _store();
    await file.writeAsString(jsonEncode(_sources.map((s) => s.toJson()).toList()), flush: true);
  }

  Future<void> _add() async {
    final uri = Uri.tryParse(_url.text.trim());
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      setState(() => _errors['form'] = 'Enter a valid HTTPS media URL.');
      return;
    }
    if (_sources.length >= 4) {
      setState(() => _errors['form'] = 'Maximum four sources in this workspace.');
      return;
    }
    final source = _MediaSource(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: _name.text.trim().isEmpty ? 'Camera ${_sources.length + 1}' : _name.text.trim(),
      url: uri.toString(),
    );
    setState(() { _sources.add(source); _errors.remove('form'); });
    _name.clear();
    _url.clear();
    try { await _save(); } catch (_) {
      if (mounted) setState(() => _errors['storage'] = 'Unable to save source list.');
    }
  }

  Future<void> _connect(_MediaSource source) async {
    setState(() { _busy = true; _errors.remove(source.id); });
    final old = _players.remove(source.id);
    await old?.dispose();
    VideoPlayerController? next;
    try {
      next = VideoPlayerController.networkUrl(Uri.parse(source.url));
      await next.initialize();
      await next.setLooping(true);
      if (!mounted) { await next.dispose(); return; }
      _players[source.id] = next;
      await next.play();
    } catch (_) {
      await next?.dispose();
      if (mounted) _errors[source.id] = 'Stream unavailable or unsupported. Check your authorized gateway.';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _disconnect(String id) async {
    final player = _players.remove(id);
    await player?.dispose();
    if (mounted) setState(() {});
  }

  Future<void> _remove(_MediaSource source) async {
    await _disconnect(source.id);
    setState(() => _sources.removeWhere((s) => s.id == source.id));
    try { await _save(); } catch (_) {
      if (mounted) setState(() => _errors['storage'] = 'Unable to save source list.');
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    for (final player in _players.values) { player.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      const Text('LIVE VIDEO & MEDIA CENTER', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      const Text('Phase 10 • Up to four view-only feeds • Local source catalog • No flight commands'),
      const SizedBox(height: 16),
      Card(child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('ADD AUTHORIZED VIDEO SOURCE', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Camera name', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: _url, decoration: const InputDecoration(labelText: 'HTTPS video URL', hintText: 'https://example.org/live.m3u8', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          FilledButton.icon(onPressed: _busy ? null : _add, icon: const Icon(Icons.add), label: const Text('ADD SOURCE')),
          if (_errors['form'] != null) Text(_errors['form']!, style: const TextStyle(color: Colors.orangeAccent)),
          if (_errors['storage'] != null) Text(_errors['storage']!, style: const TextStyle(color: Colors.orangeAccent)),
        ]),
      )),
      const SizedBox(height: 14),
      if (_sources.isEmpty) const Card(child: ListTile(
        leading: Icon(Icons.videocam_off_outlined),
        title: Text('No camera sources configured'),
        subtitle: Text('Add an authorized HTTPS media URL to start monitoring.'),
      )),
      LayoutBuilder(builder: (context, constraints) => Wrap(
        spacing: 12, runSpacing: 12,
        children: _sources.map((source) {
          final player = _players[source.id];
          final ready = player != null && player!.value.isInitialized;
          return SizedBox(
            width: constraints.maxWidth >= 740 ? (constraints.maxWidth - 12) / 2 : constraints.maxWidth,
            child: Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.videocam_outlined),
                  const SizedBox(width: 8),
                  Expanded(child: Text(source.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold))),
                  Icon(ready ? Icons.circle : Icons.circle_outlined, color: ready ? Colors.greenAccent : Colors.grey, size: 12),
                  const SizedBox(width: 6),
                  Text(ready ? 'CONNECTED' : 'OFFLINE', style: const TextStyle(fontSize: 10)),
                ]),
                const SizedBox(height: 10),
                AspectRatio(aspectRatio: 16 / 9, child: Container(
                  color: Colors.black,
                  child: ready ? AspectRatio(aspectRatio: player!.value.aspectRatio, child: VideoPlayer(player!))
                    : const Center(child: Icon(Icons.videocam_off_outlined, size: 42, color: Colors.white54)),
                )),
                if (_errors[source.id] != null) Padding(padding: const EdgeInsets.only(top: 8),
                  child: Text(_errors[source.id]!, style: const TextStyle(color: Colors.orangeAccent))),
                Wrap(spacing: 8, children: [
                  OutlinedButton.icon(onPressed: _busy ? null : () => ready ? _disconnect(source.id) : _connect(source),
                    icon: Icon(ready ? Icons.link_off : Icons.link),
                    label: Text(ready ? 'DISCONNECT' : 'CONNECT')),
                  if (ready) OutlinedButton.icon(
                    onPressed: () async {
                      if (player!.value.isPlaying) { await player!.pause(); } else { await player!.play(); }
                      if (mounted) setState(() {});
                    },
                    icon: Icon(player!.value.isPlaying ? Icons.pause : Icons.play_arrow),
                    label: Text(player!.value.isPlaying ? 'PAUSE' : 'PLAY')),
                  TextButton.icon(onPressed: () => _remove(source), icon: const Icon(Icons.delete_outline), label: const Text('REMOVE')),
                ]),
              ],
            ))),
          );
        }).toList(),
      )),
      const SizedBox(height: 12),
      const Text('Sources are saved locally on this device. Video is streamed for viewing only; recording, snapshots, media archives and mission linking are not enabled in this release. Never enter camera credentials in URLs.', style: TextStyle(color: Colors.white60, fontSize: 12)),
    ],
  );
}

class _MediaSource {
  final String id;
  final String name;
  final String url;
  const _MediaSource({required this.id, required this.name, required this.url});
  factory _MediaSource.fromJson(Map<String, dynamic> json) => _MediaSource(
    id: json['id'] as String, name: json['name'] as String, url: json['url'] as String);
  Map<String, String> toJson() => {'id': id, 'name': name, 'url': url};
}
