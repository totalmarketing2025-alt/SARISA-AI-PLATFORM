import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class SarisaMap extends StatefulWidget {
  final double height;

  const SarisaMap({super.key, required this.height});

  @override
  State<SarisaMap> createState() => _SarisaMapState();
}

class _SarisaMapState extends State<SarisaMap> {
  static const LatLng _defaultCenter = LatLng(41.9981, 21.4254);

  Position? _position;
  StreamSubscription<Position>? _positionSubscription;
  bool _requesting = false;
  String _status = 'GPS NOT REQUESTED';

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }

  Future<void> _locate() async {
    if (_requesting) return;

    setState(() {
      _requesting = true;
      _status = 'CHECKING GPS...';
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _setStatus('LOCATION SERVICES DISABLED');
        return;
      }

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        _setStatus('LOCATION PERMISSION DENIED');
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        _setStatus('PERMISSION BLOCKED IN SETTINGS');
        return;
      }

      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        _setStatus('LOCATION PERMISSION UNAVAILABLE');
        return;
      }

      if (mounted) {
        setState(() => _status = 'ACQUIRING GPS FIX...');
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );

      if (!mounted) return;

      setState(() {
        _position = position;
        _status = 'GPS ACTIVE • ±${position.accuracy.toStringAsFixed(0)} M';
      });

      await _positionSubscription?.cancel();
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen(
        (nextPosition) {
          if (!mounted) return;
          setState(() {
            _position = nextPosition;
            _status =
                'GPS ACTIVE • ±${nextPosition.accuracy.toStringAsFixed(0)} M';
          });
        },
        onError: (Object error) {
          if (mounted) _setStatus('GPS STREAM INTERRUPTED');
        },
      );
    } catch (error) {
      _setStatus('GPS ERROR • CHECK DEVICE');
    } finally {
      if (mounted) {
        setState(() => _requesting = false);
      }
    }
  }

  void _setStatus(String value) {
    if (!mounted) return;
    setState(() => _status = value);
  }

  @override
  Widget build(BuildContext context) {
    final position = _position;

    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            FlutterMap(
              key: ValueKey(position == null ? 'default-map' : 'gps-map'),
              options: MapOptions(
                initialCenter: position == null
                    ? _defaultCenter
                    : LatLng(position.latitude, position.longitude),
                initialZoom: position == null ? 6 : 15,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.sarisa',
                  maxZoom: 19,
                ),
                if (position != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: LatLng(
                          position.latitude,
                          position.longitude,
                        ),
                        width: 44,
                        height: 44,
                        child: const Icon(
                          Icons.my_location,
                          color: Color(0xFF168BFF),
                          size: 36,
                        ),
                      ),
                    ],
                  ),
                const RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution('© OpenStreetMap contributors'),
                  ],
                ),
              ],
            ),
            Positioned(
              top: 10,
              left: 10,
              right: 10,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xE6102030),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _status,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _requesting ? null : _locate,
                    icon: _requesting
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location, size: 15),
                    label: const Text(
                      'MY LOCATION',
                      style: TextStyle(fontSize: 9),
                    ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
