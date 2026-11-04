import 'package:flutter/material.dart';
import '../../../features/dji/models/dji_drone_model.dart';
import '../../map/widgets/sarisa_map.dart';

const _bg = Color(0xFF10170F);
const _panel = Color(0xFF1A2417);
const _border = Color(0xFF35452B);
const _olive = Color(0xFF8DA65A);
const _green = Color(0xFF78C46A);
const _muted = Color(0xFF9AA58F);
const _orange = Color(0xFFE2AD54);

class TacticalOpsPage extends StatelessWidget {
  const TacticalOpsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _bg,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(),
            const SizedBox(height: 18),
            _statusOverview(),
            const SizedBox(height: 18),
            _sectionTitle('TACTICAL SITUATIONAL AWARENESS', Icons.public),
            const SizedBox(height: 10),
            _mapPanel(),
            const SizedBox(height: 20),
            _sectionTitle('AIR UNIT MONITORING', Icons.flight),
            const SizedBox(height: 10),
            _droneGrid(),
            const SizedBox(height: 20),
            _sectionTitle('GROUND RESCUE TEAMS', Icons.groups),
            const SizedBox(height: 10),
            _teamPanel(),
            const SizedBox(height: 20),
            _sectionTitle('COMMUNICATIONS & SYSTEM', Icons.sensors),
            const SizedBox(height: 10),
            _communicationsPanel(),
            const SizedBox(height: 18),
            const Center(
              child: Text(
                'SARISA TACTICAL INTERFACE • MONITORING ONLY',
                style: TextStyle(
                  color: _muted,
                  fontSize: 9,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: _panel,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.radar, color: _green, size: 30),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SARISA / TACTICAL OPS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'SEARCH • RESCUE • SITUATIONAL AWARENESS',
                    style: TextStyle(color: _muted, fontSize: 9),
                  ),
                ],
              ),
            ),
            _tag('DEMO', _orange),
          ],
        ),
        const SizedBox(height: 16),
        const Divider(color: _border),
        const SizedBox(height: 8),
        const Row(
          children: [
            Icon(Icons.shield_outlined, color: _green, size: 15),
            SizedBox(width: 7),
            Expanded(
              child: Text(
                'TACTICAL MONITORING WORKSPACE',
                style: TextStyle(
                  color: _green,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
            Text(
              'VIEW ONLY',
              style: TextStyle(color: _muted, fontSize: 9),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _statusOverview() => LayoutBuilder(
    builder: (context, constraints) {
      final width = (constraints.maxWidth - 18) / 2;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          SizedBox(width: width, child: _metric('DRONES', '0 / 4', Icons.flight, _orange)),
          SizedBox(width: width, child: _metric('GROUND TEAMS', '0 CONNECTED', Icons.groups, _orange)),
          SizedBox(width: width, child: _metric('GPS STATUS', 'REQUEST ON MAP', Icons.gps_off, _orange)),
          SizedBox(width: width, child: _metric('MAP FEED', 'OPENSTREETMAP', Icons.map_outlined, _green)),
        ],
      );
    },
  );

  Widget _metric(String title, String value, IconData icon, Color color) =>
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _border),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 23),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: _muted, fontSize: 9)),
                  const SizedBox(height: 5),
                  Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _sectionTitle(String title, IconData icon) => Row(
    children: [
      Icon(icon, color: _olive, size: 17),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          title,
          style: const TextStyle(
            color: _olive,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.1,
          ),
        ),
      ),
      Container(width: 35, height: 1, color: _border),
    ],
  );

  Widget _mapPanel() => const SarisaMap(height: 290);

  Widget _droneGrid() => Column(
    children: List.generate(4, (index) {
      final model = DjiDroneModel.catalog[index];
      return Container(
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _border),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: _olive.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.flight, color: _olive),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AIR UNIT 0${index + 1}',
                    style: const TextStyle(color: _muted, fontSize: 9),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    model.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'GPS —  |  BATTERY —  |  SIGNAL —',
                    style: TextStyle(color: _muted, fontSize: 8),
                  ),
                ],
              ),
            ),
            _tag('OFFLINE', _orange),
          ],
        ),
      );
    }),
  );

  Widget _teamPanel() => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: _panel,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: _border),
    ),
    child: const Column(
      children: [
        _TeamRow('TEAM ALPHA', 'Position unavailable'),
        Divider(color: _border),
        _TeamRow('TEAM BRAVO', 'Position unavailable'),
        Divider(color: _border),
        _TeamRow('TEAM CHARLIE', 'Position unavailable'),
      ],
    ),
  );

  Widget _communicationsPanel() => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: _panel,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: _border),
    ),
    child: const Column(
      children: [
        _SystemRow('DJI integration', 'NOT CONNECTED'),
        _SystemRow('GPS service', 'NOT CONNECTED'),
        _SystemRow('Map provider', 'NOT CONFIGURED'),
        _SystemRow('Communication gateway', 'NOT CONFIGURED'),
        _SystemRow('Mission database', 'NOT CONFIGURED'),
      ],
    ),
  );

  Widget _tag(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .10),
      borderRadius: BorderRadius.circular(5),
      border: Border.all(color: color.withValues(alpha: .35)),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: 8,
        fontWeight: FontWeight.bold,
        letterSpacing: .5,
      ),
    ),
  );
}

class _TeamRow extends StatelessWidget {
  final String name;
  final String detail;
  const _TeamRow(this.name, this.detail);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Row(
      children: [
        const Icon(Icons.groups_outlined, color: _olive, size: 19),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            name,
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
        ),
        Text(detail, style: const TextStyle(color: _muted, fontSize: 9)),
      ],
    ),
  );
}

class _SystemRow extends StatelessWidget {
  final String name;
  final String status;
  const _SystemRow(this.name, this.status);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        const Icon(Icons.circle, color: _orange, size: 7),
        const SizedBox(width: 10),
        Expanded(
          child: Text(name, style: const TextStyle(color: Colors.white, fontSize: 11)),
        ),
        Text(
          status,
          style: const TextStyle(
            color: _orange,
            fontSize: 8,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}
