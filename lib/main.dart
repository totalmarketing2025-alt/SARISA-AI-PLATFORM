import 'package:flutter/material.dart';
import 'features/media/screens/tactical_camera_wall.dart';
import 'features/missions/screens/mission_planning_page.dart';
import 'features/media/screens/media_center_page.dart';
import 'features/ai/screens/ai_analysis_page.dart';
import 'features/simulation/screens/simulation_ops_page.dart';
import 'package:video_player/video_player.dart';
import 'features/dji/screens/dji_fleet_page.dart';
import 'features/cases/screens/case_management_page.dart';
import 'features/map/widgets/sarisa_map.dart';
import 'features/tactical/screens/tactical_ops_page.dart';

void main() => runApp(const SarisaApp());

const navy = Color(0xFF09120F);
const panel = Color(0xFF15251C);
const blue = Color(0xFFB9D88D);
const green = Color(0xFF9BCB78);
const muted = Color(0xFF9BAD9E);

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

/// Stylized sarissa spear crossed with a contemporary radar reticle.
/// Vector-drawn so it stays sharp in headers and at small sizes.
class SarisaEmblem extends StatelessWidget {
  final double size;
  const SarisaEmblem({super.key, this.size = 42});
  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size),
      painter: _SarisaEmblemPainter());
}

class _SarisaEmblemPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final gold = Paint()..color = const Color(0xFFD8B66B)
      ..strokeWidth = s * .075..strokeCap = StrokeCap.round;
    final ring = Paint()..color = const Color(0xFF8BBF83)
      ..style = PaintingStyle.stroke..strokeWidth = s * .04;
    final center = Offset(s * .5, s * .5);
    canvas.drawCircle(center, s * .32, ring);
    canvas.drawArc(Rect.fromCircle(center: center, radius: s * .40),
        -.75, 1.50, false, ring);
    canvas.drawLine(Offset(s * .12, s * .83), Offset(s * .79, s * .17), gold);
    final tip = Path()..moveTo(s * .72, s * .12)
      ..lineTo(s * .96, s * .04)..lineTo(s * .87, s * .29)..close();
    canvas.drawPath(tip, Paint()..color = const Color(0xFFE5C980));
    canvas.drawCircle(center, s * .06, Paint()..color = const Color(0xFFE5C980));
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class SarisaShell extends StatefulWidget {
  const SarisaShell({super.key});
  @override
  State<SarisaShell> createState() => _SarisaShellState();
}

class _SarisaShellState extends State<SarisaShell> {
  int selected = 0;
  static const pages = <Widget>[
    DashboardPage(), TacticalOpsPage(), TacticalCameraWall(),
    AiAnalysisPage(), MissionPlanningPage(), CaseManagementPage(),
    MediaCenterPage(), FlightPage(), DjiFleetPage(),
    SimulationOpsPage(), SettingsPage(),
  ];
  static const labels = <String>[
    'COMMAND CENTER', 'TACTICAL OPS', 'CAMERA WALL', 'AI INTELLIGENCE',
    'MISSION CONTROL', 'SEARCH CASES', 'MEDIA SOURCES', 'FLIGHT DATA',
    'DJI FLEET', 'SIMULATOR', 'SYSTEM SETTINGS',
  ];
  static const icons = <IconData>[
    Icons.dashboard_customize_outlined, Icons.radar, Icons.grid_view,
    Icons.center_focus_strong, Icons.route, Icons.folder_shared_outlined,
    Icons.video_library_outlined, Icons.sensors, Icons.flight,
    Icons.science_outlined, Icons.settings_outlined,
  ];
  void _go(int index) => setState(() => selected = index);

  Widget _navigation({required bool wide}) => Container(
    width: wide ? 232 : null, color: const Color(0xFF101D16),
    child: Column(children: [
      const Padding(padding: EdgeInsets.fromLTRB(16, 24, 12, 18),
        child: Row(children: [
          const SarisaEmblem(size: 48), const SizedBox(width: 10),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('SARISA', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900,
                  letterSpacing: 2, color: Color(0xFFE2C37A))),
              Text('TACTICAL COMMAND', style: TextStyle(fontSize: 9, color: muted)),
            ])),
        ])),
      const Divider(color: Color(0xFF385440), height: 1),
      Expanded(child: ListView(padding: const EdgeInsets.all(8),
        children: List.generate(labels.length, (i) => ListTile(
          dense: true,
          selected: selected == i,
          selectedTileColor: const Color(0xFF293F2C),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          leading: Icon(icons[i], color: selected == i ? blue : muted, size: 21),
          title: Text(labels[i], style: TextStyle(fontSize: 11, letterSpacing: .5,
              color: selected == i ? Colors.white : muted,
              fontWeight: selected == i ? FontWeight.bold : FontWeight.normal)),
          onTap: () { _go(i); if (!wide) Navigator.pop(context); },
        )))),
      const Padding(padding: EdgeInsets.all(12),
        child: Text('SARISSA HERITAGE  /  MODERN INTELLIGENCE',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 8, color: muted))),
    ]),
  );

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
      drawer: wide ? null : Drawer(child: _navigation(wide: false)),
      body: Row(children: [
        if (wide) _navigation(wide: true),
        Expanded(child: Column(children: [
          Container(height: 62, padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: const BoxDecoration(color: Color(0xFF101D16),
              border: Border(bottom: BorderSide(color: Color(0xFF385440)))),
            child: Row(children: [
              if (!wide) Builder(builder: (ctx) => IconButton(
                tooltip: 'Open all modules', icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(ctx).openDrawer())),
              if (!wide) const SarisaEmblem(size: 30),
              if (!wide) const SizedBox(width: 8),
              Expanded(child: Text(labels[selected], overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900,
                  letterSpacing: 1.0, color: Color(0xFFD8C38C)))),
              const Icon(Icons.circle, size: 9, color: Color(0xFFE3B36A)),
              const SizedBox(width: 6),
              const Text('DEMO / NO DRONE LINK',
                style: TextStyle(color: Color(0xFFE3B36A), fontSize: 9)),
            ])),
          Expanded(child: IndexedStack(index: selected, children: pages)),
        ])),
      ]),
      bottomNavigationBar: wide ? null : SafeArea(top: false, child: Container(
        color: const Color(0xFF101D16), height: 66,
        child: Row(children: [
          for (final i in [0, 1, 2, 3, 4])
            Expanded(child: InkWell(onTap: () => _go(i),
              child: Column(mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icons[i], size: 20, color: selected == i ? blue : muted),
                  const SizedBox(height: 5),
                  Text(i == 0 ? 'HOME' : i == 1 ? 'OPS' : i == 2 ? 'CAMERAS' :
                      i == 3 ? 'AI' : 'MISSIONS',
                    style: TextStyle(fontSize: 9, color: selected == i ? blue : muted)),
                ]))),
        ]),
      )),
    );
  }
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
        SizedBox(width: 205, child: metric('AIR UNIT', 'NOT CONNECTED', Icons.air, color: muted)),
        SizedBox(width: 205, child: metric('BATTERY', '—', Icons.battery_5_bar, color: muted)),
      ]),
      const SizedBox(height: 16),
      const Card(child: Padding(padding: EdgeInsets.all(18), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(Icons.map_outlined, color: blue), SizedBox(width: 9),
            Text('AREA OVERVIEW', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1))]),
          SizedBox(height: 14),
          SarisaMap(height: 260),
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
