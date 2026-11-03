import 'package:flutter/material.dart';
import '../models/dji_drone_model.dart';

class _DroneSlot {
  String modelId;
  String mode;

  _DroneSlot({required this.modelId}) : mode = 'RC';
}

class DjiFleetPage extends StatefulWidget {
  const DjiFleetPage({super.key});

  @override
  State<DjiFleetPage> createState() => _DjiFleetPageState();
}

class _DjiFleetPageState extends State<DjiFleetPage> {
  final List<_DroneSlot> slots = [
    _DroneSlot(modelId: 'mini4pro'),
    _DroneSlot(modelId: 'mavic3e'),
    _DroneSlot(modelId: 'matrice30'),
    _DroneSlot(modelId: 'matrice350'),
  ];

  DjiDroneModel getModel(String id) =>
      DjiDroneModel.catalog.firstWhere((item) => item.id == id);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'DJI FLEET CONTROL',
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900, letterSpacing: 1),
          ),
          const SizedBox(height: 5),
          const Text(
            'Universal drone monitoring interface',
            style: TextStyle(color: Color(0xFF8FA7B8), fontSize: 12),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _statusChip(Icons.radar, 'FLEET MONITOR', const Color(0xFF19D39A)),
              _statusChip(Icons.sensors_off, 'NO LIVE CONNECTION', Colors.orange),
              _statusChip(Icons.visibility_outlined, 'VIEW ONLY', const Color(0xFF19A7F5)),
            ],
          ),
          const SizedBox(height: 22),
          const Text(
            'ACTIVE MONITORING SLOTS',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1),
          ),
          const SizedBox(height: 10),
          ...List.generate(slots.length, (index) => _droneCard(index)),
          const SizedBox(height: 22),
          const Text(
            'SUPPORTED DJI MODELS',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1),
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: DjiDroneModel.catalog.map((model) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.flight, color: Color(0xFF19A7F5)),
                  title: Text(model.name, style: const TextStyle(fontSize: 13)),
                  trailing: Text(
                    model.category.toUpperCase(),
                    style: const TextStyle(fontSize: 9, color: Color(0xFF8FA7B8)),
                  ),
                )).toList(),
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Colors.orange),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Telemetry is not connected. No live position, battery, video or flight data is being received. This module is currently a configuration and monitoring interface only.',
                      style: TextStyle(fontSize: 11, height: 1.5, color: Color(0xFFB7C8D3)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: .35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _droneCard(int index) {
    final slot = slots[index];
    final model = getModel(slot.modelId);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF19A7F5).withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(Icons.flight, color: Color(0xFF19A7F5)),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('DRONE SLOT 0${index + 1}',
                        style: const TextStyle(fontSize: 9, color: Color(0xFF8FA7B8), letterSpacing: 1)),
                      const SizedBox(height: 3),
                      Text(model.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                ),
                const Icon(Icons.circle, color: Colors.orange, size: 9),
                const SizedBox(width: 5),
                const Text('OFFLINE', style: TextStyle(fontSize: 9, color: Colors.orange)),
              ],
            ),
            const SizedBox(height: 14),
            const Text('AIRCRAFT MODEL', style: TextStyle(fontSize: 9, color: Color(0xFF8FA7B8))),
            const SizedBox(height: 5),
            DropdownButtonFormField<String>(
              initialValue: slot.modelId,
              isExpanded: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              items: DjiDroneModel.catalog.map((item) => DropdownMenuItem(
                value: item.id,
                child: Text(item.name, style: const TextStyle(fontSize: 12)),
              )).toList(),
              onChanged: (value) {
                if (value != null) setState(() => slot.modelId = value);
              },
            ),
            const SizedBox(height: 12),
            const Text('INTEGRATION MODE', style: TextStyle(fontSize: 9, color: Color(0xFF8FA7B8))),
            const SizedBox(height: 5),
            DropdownButtonFormField<String>(
              initialValue: slot.mode,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              items: const [
                DropdownMenuItem(value: 'RC', child: Text('RC — Remote Controller')),
                DropdownMenuItem(value: 'Cloud', child: Text('Cloud — Cloud Integration')),
                DropdownMenuItem(value: 'Hybrid', child: Text('Hybrid — RC + Cloud')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => slot.mode = value);
              },
            ),
            const SizedBox(height: 10),
            const Row(
              children: [
                Icon(Icons.link_off, size: 13, color: Colors.orange),
                SizedBox(width: 6),
                Text('Connection not configured',
                  style: TextStyle(fontSize: 10, color: Colors.orange)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
