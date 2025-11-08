import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

import '../services/mobidata_api.dart';
import '../models/parking_site.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MapController _mapController = MapController();
  final MobiDataApi _api = MobiDataApi();

  List<ParkingSite> _sites = [];
  bool _loading = false;
  String? _error;

  LatLng _center = const LatLng(48.7758, 9.1829); // test location
  double _zoom = 13.0;

  // nicht jedes mal daten pullen wenn karte bewegt wird
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _ensureLocation();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _ensureLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever || permission == LocationPermission.denied) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      setState(() {
        _center = LatLng(pos.latitude, pos.longitude);
        _zoom = 18.0;
      });
      _mapController.move(_center, _zoom);
    } catch (_) {
      // ignorieren
    }
  }

  // test: bounding box
  /*
  LatLngBounds _currentBounds() {
    final center = _center;
    final delta = 0.05; // roughly 5-6 km radius
    return LatLngBounds(
      LatLng(center.latitude - delta, center.longitude - delta),
      LatLng(center.latitude + delta, center.longitude + delta),
    );
  }
  */

  // live karten ausschnitt verwenden
  LatLngBounds _currentBounds() {
    final bounds = _mapController.camera.visibleBounds;
    return bounds ??
        LatLngBounds(
          LatLng(_center.latitude - 0.05, _center.longitude - 0.05),
          LatLng(_center.latitude + 0.05, _center.longitude + 0.05),
        );
  }

  // debouncing
  void _onMapMovedDebounced() {
    // alten Timer abbrechen wenn noch aktiv
    _debounce?.cancel();

    _debounce = Timer(const Duration(milliseconds: 600), () {
      // nach kurzer ruhepause
      _loadParking();
    });
  }

  Future<void> _loadParking() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      print('[HomeScreen] loading parking…');

      // daten abrufen
      final allSites = await _api.fetchParkingSites();
      print('[HomeScreen] got ${allSites.length} total');

      // kartenbegrenzung
      final b = _currentBounds();

      // filtern
      final filtered = allSites.where((s) {
        if (s.lat == null || s.lon == null) return false;
        return s.lat! >= b.south &&
            s.lat! <= b.north &&
            s.lon! >= b.west &&
            s.lon! <= b.east;
      }).toList();

      print('[HomeScreen] filtered sites in bbox: ${filtered.length}');

      setState(() {
        _sites = filtered;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
      print('[HomeScreen] error: $e');
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  // test, ob daten reinkommen: lade ALLE parkplätze
  /*
  Future<void> _loadParking() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      print('[HomeScreen] loading parking…');
      final sites = await _api.fetchParkingSites();
      print('[HomeScreen] got ${sites.length} sites total');

      // nicht filtern
      setState(() {
        _sites = sites;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
      print('[HomeScreen] error: $e');
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }
  */

  @override
  Widget build(BuildContext context) {
    final markers = _sites.where((s) => s.lat != null && s.lon != null).map((s) {
      return Marker(
        width: 40,
        height: 40,
        point: LatLng(s.lat!, s.lon!),
        child: GestureDetector(
          onTap: () {
            showModalBottomSheet(
              context: context,
              builder: (_) => _ParkingSheet(site: s),
            );
          },
          child: const Icon(Icons.local_parking, size: 32),
        ),
      );
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('MobiData BW'),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: _zoom,
              onPositionChanged: (pos, hasGesture) {
                _center = pos.center ?? _center;
                _zoom = pos.zoom ?? _zoom;

                // nur bei benutzer bewegung reagieren
                if (hasGesture == true) {
                  _onMapMovedDebounced();
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.mobidata-bw-flutter',
              ),
              MarkerLayer(markers: markers),
            ],
          ),
          if (_loading)
            Positioned.fill(
              child: ColoredBox(
                color: const Color(0x11000000),
                child: const Center(
                  child: SpinKitFadingCircle(
                    size: 48,
                    color: Colors.white, // oder eine andere Farbe
                  ),
                ),
              ),
            ),
          if (_error != null)
            Positioned(
              left: 12, right: 12, bottom: 90,
              child: Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text('Fehler: $_error'),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loadParking,
        icon: const Icon(Icons.download),
        label: const Text('Parkplätze laden'),
      ),
    );
  }
}

class _ParkingSheet extends StatelessWidget {
  final ParkingSite site;
  const _ParkingSheet({required this.site});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(site.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (site.capacity != null) Text('Kapazität: ${site.capacity}'),
            if (site.state != null) Text('Status: ${site.state}'),
            if (site.lat != null && site.lon != null)
              Text('Position: ${site.lat!.toStringAsFixed(5)}, ${site.lon!.toStringAsFixed(5)}'),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.close),
                  label: const Text('Schließen'),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
