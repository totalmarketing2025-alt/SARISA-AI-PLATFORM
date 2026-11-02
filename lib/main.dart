import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

void main() => runApp(const SarisaApp());

const navy = Color(0xFF071522);
const panel = Color(0xFF102638);
const blue = Color(0xFF19A7F5);
const green = Color(0xFF19D39A);
const muted = Color(0xFF8FA7B8);

class SarisaApp extends StatelessWidget {
  const SarisaApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'SARISA',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: navy,
          colorScheme: const ColorScheme.dark(
            primary: blue, secondary: green, surface: panel,
          ),
          useMaterial3: true,
          cardTheme: CardThemeData(
            color: panel, elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: Color(0xFF1C4058)),
            ),
          ),
        ),
        home: const SarisaShell(),
      );
}

class SarisaShell extends StatefulWidget {
  const SarisaShell({super.key});
  @override
  State<SarisaShell> createState() => _SarisaShellState();
}

class _SarisaShellState extends State<SarisaShell> {
  int selected = 0;
  final pages = const [
    DashboardPage(), MissionPage(), SearchPage(), VideoPage(), FlightPage(), SettingsPage()
  ];
  final labels = const ['Overview', 'Missions', 'Search cases', 'Video link', 'Flight data', 'Settings'];
  final icons = const [
    Icons.dashboard_outlined, Icons.route, Icons.manage_search,
    Icons.videocam_outlined, Icons.sensors, Icons.settings_outlined
  ];

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 850;
    return Scaffold(
      body: Row(children: [
        if (wide) _sidebar(),
        Expanded(child: Column(children: [
          _topbar(),
          Expanded(child: IndexedStack(index: selected, children: pages)),
        ])),
      ]),
      bottomNavigationBar: wide ? null : NavigationBar(
        selectedIndex: selected,
        onDestinationSelected: (v) => setState(() => selected = v),
        destinations: List.generate(5, (i) => NavigationDestination(
          icon: Icon(icons[i]), label: labels[i],
        )),
      ),
    );
  }

  Widget _sidebar() => Container(
    width: 230, color: const Color(0xFF091B2A),
    padding: const EdgeInsets.all(18),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 14),
      const Row(children: [
        Icon(Icons.radar, color: green, size: 30),
        SizedBox(width: 10),
        Text('SARISA', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, letterSpacing: 2)),
      ]),
      const Text('SEARCH • RESCUE • AWARENESS', style: TextStyle(fontSize: 8, color: muted)),
      const SizedBox(height: 34),
      ...List.generate(labels.length, (i) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Material(
          color: Colors.transparent,
          child: ListTile(
          selected: selected == i,
          selectedTileColor: const Color(0xFF123B55),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          leading: Icon(icons[i], color: selected == i ? green : muted),
          title: Text(labels[i], style: const TextStyle(fontSize: 13)),
          onTap: () => setState(() => selected = i),
          ),
        ),
      )),
      const Spacer(),
      const Text('SARISA CORE  •  DEMO MODE', style: TextStyle(color: muted, fontSize: 9)),
    ]),
  );

  Widget _topbar() => Container(
    height: 66, padding: const EdgeInsets.symmetric(horizontal: 22),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: Color(0xFF1C3548))),
    ),
    child: Row(children: [
      const Text('SYSTEM / ', style: TextStyle(color: muted, fontSize: 11)),
      Text(labels[selected].toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
      const Spacer(),
      const Icon(Icons.circle, color: green, size: 9),
      const SizedBox(width: 7),
      const Text('SYSTEM ONLINE', style: TextStyle(color: green, fontSize: 10, fontWeight: FontWeight.bold)),
      const SizedBox(width: 18),
      const CircleAvatar(radius: 15, backgroundColor: Color(0xFF1B4964), child: Icon(Icons.person_outline, size: 18)),
    ]),
  );
}

class PageFrame extends StatelessWidget {
  final String title, subtitle;
  final List<Widget> children;
  const PageFrame({super.key, required this.title, required this.subtitle, required this.children});
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(22),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
      const SizedBox(height: 5),
      Text(subtitle, style: const TextStyle(color: muted, fontSize: 12)),
      const SizedBox(height: 20),
      ...children,
    ]),
  );
}

Widget metric(String name, String value, IconData icon, {Color color = blue}) => Card(
  child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
    Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(
      color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, color: color)),
    const SizedBox(width: 12),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(name, style: const TextStyle(color: muted, fontSize: 11)),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 19)),
    ])),
  ])),
);

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});
  @override
  Widget build(BuildContext context) => PageFrame(
    title: 'Operations overview',
    subtitle: 'Situational awareness • Search and rescue • Operator-supervised missions',
    children: [
      Wrap(spacing: 12, runSpacing: 12, children: [
        SizedBox(width: 205, child: metric('AIR UNIT', 'STANDBY', Icons.air, color: green)),
        SizedBox(width: 205, child: metric('BATTERY', '87%', Icons.battery_5_bar)),
        SizedBox(width: 205, child: metric('GPS FIX', '3D / GOOD', Icons.gps_fixed, color: green)),
        SizedBox(width: 205, child: metric('LINK STATUS', 'CONNECTED', Icons.wifi, color: green)),
      ]),
      const SizedBox(height: 16),
      Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [Icon(Icons.map_outlined, color: blue), SizedBox(width: 9),
            Text('AREA OVERVIEW', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1))]),
          const SizedBox(height: 14),
          Container(height: 260, width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: const LinearGradient(colors: [Color(0xFF102D3C), Color(0xFF173B45)]),
            ),
            child: const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.public, size: 52, color: Color(0xFF4A8393)),
              SizedBox(height: 10),
              Text('MAP PROVIDER NOT CONFIGURED', style: TextStyle(color: muted, fontSize: 11)),
              Text('Connect an approved map tile provider in Settings', style: TextStyle(color: muted, fontSize: 10)),
            ]))),
        ],
      ))),
      const SizedBox(height: 16),
      const Text('RECENT SYSTEM EVENTS', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
      const SizedBox(height: 8),
      const EventRow('System initialized', 'All local modules loaded', green),
      const EventRow('Flight controller', 'No physical drone connected • Demo mode', blue),
      const EventRow('Search workspace', 'No active search cases', muted),
    ],
  );
}

class EventRow extends StatelessWidget {
  final String title, detail; final Color color;
  const EventRow(this.title, this.detail, this.color, {super.key});
  @override
  Widget build(BuildContext context) => Card(child: ListTile(
    leading: Icon(Icons.circle, color: color, size: 9),
    title: Text(title, style: const TextStyle(fontSize: 13)),
    subtitle: Text(detail, style: const TextStyle(color: muted, fontSize: 11)),
  ));
}

class MissionPage extends StatelessWidget {
  const MissionPage({super.key});
  @override
  Widget build(BuildContext context) => PageFrame(
    title: 'Mission management',
    subtitle: 'Create and document operator-supervised Search & Rescue missions',
    children: [
      Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('NEW SEARCH & RESCUE MISSION', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          const TextField(decoration: InputDecoration(labelText: 'Mission name', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          const TextField(maxLines: 2, decoration: InputDecoration(labelText: 'Area / notes', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Mission form is a local prototype; persistence is not configured.'))),
            icon: const Icon(Icons.add), label: const Text('CREATE DRAFT')),
        ],
      ))),
      const SizedBox(height: 12),
      const EventRow('No missions yet', 'New missions will appear here', muted),
    ],
  );
}

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});
  @override
  State<SearchPage> createState() => _SearchPageState();
}
class _SearchPageState extends State<SearchPage> {
  String? fileName;
  String? filePath;
  @override
  Widget build(BuildContext context) => PageFrame(
    title: 'Search cases',
    subtitle: 'Upload reference material and record non-identifying visual observations',
    children: [
      Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('REFERENCE IMAGE UPLOAD', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Attach a photo to a case record for human review. This prototype does not perform face recognition, identity matching, or person tracking.',
            style: TextStyle(color: muted, fontSize: 12)),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () async {
              final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: false);
              if (result != null && result.files.single.path != null) {
                setState(() { fileName = result.files.single.name; filePath = result.files.single.path; });
              }
            },
            icon: const Icon(Icons.upload_file), label: const Text('UPLOAD IMAGE'),
          ),
          if (fileName != null) ...[
            const SizedBox(height: 12),
            Text(fileName!, style: const TextStyle(color: green)),
            if (filePath != null) ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.file(File(filePath!), height: 180, fit: BoxFit.contain),
            ),
          ],
        ],
      ))),
      const SizedBox(height: 14),
      const Card(child: Padding(padding: EdgeInsets.all(18), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('VISUAL OBSERVATION', style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text('Future approved computer-vision integration can classify broad scene objects (for example, person, vehicle, smoke, or debris) without identifying individuals.',
            style: TextStyle(color: muted, fontSize: 12)),
        ],
      ))),
    ],
  );
}

class VideoPage extends StatefulWidget {
  const VideoPage({super.key});
  @override
  State<VideoPage> createState() => _VideoPageState();
}
class _VideoPageState extends State<VideoPage> {
  final controller = TextEditingController();
  VideoPlayerController? player;
  String? error;
  Future<void> load() async {
    await player?.dispose();
    setState(() { error = null; player = null; });
    try {
      final p = VideoPlayerController.networkUrl(Uri.parse(controller.text.trim()));
      await p.initialize();
      if (!mounted) { await p.dispose(); return; }
      setState(() => player = p);
    } catch (_) {
      if (mounted) setState(() => error = 'Could not open this stream. Check the URL and supported stream format.');
    }
  }
  @override
  void dispose() { controller.dispose(); player?.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => PageFrame(
    title: 'Drone video link',
    subtitle: 'View-only stream monitor • Compatible URL/format depends on the camera gateway',
    children: [
      Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(children: [
        TextField(controller: controller, decoration: const InputDecoration(
          labelText: 'Video stream URL (HTTPS / supported media URL)',
          hintText: 'https://example.org/stream.m3u8', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        Align(alignment: Alignment.centerLeft, child: FilledButton.icon(
          onPressed: load, icon: const Icon(Icons.link), label: const Text('CONNECT VIDEO LINK'))),
        const SizedBox(height: 16),
        if (player != null && player!.value.isInitialized)
          AspectRatio(aspectRatio: player!.value.aspectRatio,
            child: Stack(alignment: Alignment.bottomCenter, children: [
              VideoPlayer(player!),
              VideoProgressIndicator(player!, allowScrubbing: true),
              Align(alignment: Alignment.center, child: IconButton.filled(
                onPressed: () => setState(() => player!.value.isPlaying ? player!.pause() : player!.play()),
                icon: Icon(player!.value.isPlaying ? Icons.pause : Icons.play_arrow))),
            ]))
        else Container(height: 210, width: double.infinity,
          decoration: BoxDecoration(color: navy, borderRadius: BorderRadius.circular(10)),
          child: const Center(child: Icon(Icons.videocam_outlined, size: 54, color: muted))),
        if (error != null) Padding(padding: const EdgeInsets.only(top: 10),
          child: Text(error!, style: const TextStyle(color: Colors.orangeAccent))),
        const SizedBox(height: 8),
        const Text('Use only authorized camera streams. This screen displays video and does not issue flight commands.',
          style: TextStyle(color: muted, fontSize: 11)),
      ]))),
    ],
  );
}

class FlightPage extends StatelessWidget {
  const FlightPage({super.key});
  @override
  Widget build(BuildContext context) => PageFrame(
    title: 'Flight data & safety',
    subtitle: 'Telemetry dashboard and non-operational control simulator',
    children: [
      Wrap(spacing: 12, runSpacing: 12, children: [
        SizedBox(width: 190, child: metric('ALTITUDE', '— m', Icons.height)),
        SizedBox(width: 190, child: metric('GROUND SPEED', '— m/s', Icons.speed)),
        SizedBox(width: 190, child: metric('WIND', '— m/s', Icons.air)),
        SizedBox(width: 190, child: metric('BATTERY', '— %', Icons.battery_unknown)),
      ]),
      const SizedBox(height: 16),
      Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('CONTROL PANEL — SIMULATOR ONLY', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Physical flight commands are intentionally not connected in this starter project. Use the simulator for layout and operator workflow testing.',
            style: TextStyle(color: muted, fontSize: 12)),
          const SizedBox(height: 14),
          Wrap(spacing: 10, runSpacing: 10, children: [
            OutlinedButton.icon(onPressed: null, icon: const Icon(Icons.flight_takeoff), label: const Text('TAKE OFF')),
            OutlinedButton.icon(onPressed: null, icon: const Icon(Icons.home), label: const Text('RETURN HOME')),
            OutlinedButton.icon(onPressed: null, icon: const Icon(Icons.pause_circle), label: const Text('HOLD')),
            OutlinedButton.icon(onPressed: null, icon: const Icon(Icons.emergency), label: const Text('EMERGENCY')),
          ]),
          const SizedBox(height: 8),
          const Text('Controls disabled until a separately reviewed, certified safety integration is designed.',
            style: TextStyle(color: Colors.orangeAccent, fontSize: 11)),
        ],
      ))),
    ],
  );
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) => const PageFrame(
    title: 'System settings',
    subtitle: 'Integration configuration placeholders',
    children: [
      EventRow('Drone adapter', 'Not connected • adapter interface to be implemented', blue),
      EventRow('Map provider', 'API key and provider configuration required', muted),
      EventRow('Communication gateway', 'GSM / Wi-Fi / Bluetooth / radio adapters not configured', muted),
      EventRow('Security', 'Authentication, encryption and audit backend required before deployment', green),
      EventRow('Platform', 'Flutter • Android and Windows', green),
    ],
  );
}
