import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/park_api_service.dart';
import '../services/carsharing_api_service.dart';

import '../models/app_theme_setting.dart';
import '../models/parking_site.dart';
import '../models/carsharing_offer.dart';
import '../models/bikesharing_offer.dart';
import '../models/scooter_offer.dart';
import '../models/transit.dart';
import '../models/charging_station.dart';
import '../models/construction_site.dart';
import '../models/bicycle_network.dart';

import '../widgets/settings_sheet.dart';
import '../widgets/drawer_hint.dart';
import '../widgets/imprint_sheet.dart';
import '../widgets/filter_bar.dart';
import '../widgets/map_attribution.dart';
import '../widgets/parking_info_card.dart';

enum DatasetCategory {
  parking,
  carsharing,
  bikesharing,
  scooters,
  transit,
  charging,
  construction,
  bicycleNetwork,
}

class HomeScreen extends StatefulWidget {
  final AppThemeSetting appThemeSetting;
  final ValueChanged<AppThemeSetting> onChangeAppTheme;

  const HomeScreen({
    super.key,
    required this.appThemeSetting,
    required this.onChangeAppTheme,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // settings
  bool _drawerShownOnce = false;
  bool _showDrawerHint = true;

  bool _autoLoadOnMove = true;
  bool _openDrawerOnStart = true;

  static const _prefsKeyAutoLoadOnMove = 'settings_autoLoadOnMove';
  static const _prefsKeyOpenDrawerOnStart = 'settings_openDrawerOnStart';
  static const _prefsKeyDrawerHintShown = 'drawerHintShown';

  // daten und karte
  final MapController _mapController = MapController();
  final ParkApiService _parkApiService = ParkApiService();
  final CarsharingApiService _carsharingApi = CarsharingApiService();

  LatLng _center = const LatLng(48.5216, 9.0576);
  double _zoom = 13.0;

  bool _loading = false;
  String? _error;
  Timer? _debounce;
  bool _showFilterBar = false;

  DatasetCategory _selectedCategory = DatasetCategory.parking;

  // parkplätze
  List<ParkingSite> _sites = [];
  ParkingSite? _selectedSite;
  bool _showOnlyAvailable = false;

  // carsharing

  // bikesharing

  // scooter

  // transit

  // charging

  // construction

  // bicycle network

  // init
  @override
  void initState() {
    super.initState();

    _ensureLocation();

    _loadDrawerHintPreference().then((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_drawerShownOnce) {
          _drawerShownOnce = true;
          _scaffoldKey.currentState?.openDrawer();
        }
      });
    });

    _loadParking();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  // lade einstellungen
  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      _autoLoadOnMove = prefs.getBool(_prefsKeyAutoLoadOnMove) ?? true;
      _openDrawerOnStart = prefs.getBool(_prefsKeyOpenDrawerOnStart) ?? true;

      final hintShown = prefs.getBool(_prefsKeyDrawerHintShown) ?? false;
      _showDrawerHint = !hintShown;
    });
  }

  Future<void> _setAutoLoadOnMove(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKeyAutoLoadOnMove, value);
    setState(() {
      _autoLoadOnMove = value;
    });
  }

  Future<void> _setOpenDrawerOnStart(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKeyOpenDrawerOnStart, value);
    setState(() {
      _openDrawerOnStart = value;
    });
  }

  Future<void> _markDrawerHintAsShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKeyDrawerHintShown, true);
    setState(() {
      _showDrawerHint = false;
    });
  }

  // kleinen hinweis beim ersten start anzeigen
  Future<void> _loadDrawerHintPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final shown = prefs.getBool('drawerHintShown') ?? false;
    setState(() {
      _showDrawerHint = !shown;
    });
  }

  Future<void> _ensureLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      setState(() {
        _center = LatLng(pos.latitude, pos.longitude);
        _zoom = 13.0;
      });
      _mapController.move(_center, _zoom);
    } catch (_) {
      // ignorieren
    }
  }

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
    // alten timer abbrechen wenn noch aktiv
    _debounce?.cancel();

    _debounce = Timer(const Duration(milliseconds: 600), () {
      // kurze ruhepause
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
      final allSites = await _parkApiService.fetchParkingSites();

      print('[HomeScreen] got ${allSites.length} total');

      // kartenbegrenzung
      final b = _currentBounds();

      final filtered = allSites.where((s) {
        if (s.lat == null || s.lon == null) return false;

        if (!(s.lat! >= b.south &&
            s.lat! <= b.north &&
            s.lon! >= b.west &&
            s.lon! <= b.east)) {
          return false;
        }

        if (_showOnlyAvailable) {
          if (!(s.availableSpaces != null && s.availableSpaces! > 0)) {
            return false;
          }
        }

        return true;
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

  Color _statusColor(ParkingSite s) {
    switch (s.status) {
      case 'free':
        return Colors.green.shade700;
      case 'full':
        return Colors.red.shade700;
      case 'closed':
        return Colors.grey.shade700;
      default:
        return Colors.blue.shade700;
    }
  }

  ////////////////////////////////////////
  /// BUILD
  ////////////////////////////////////////

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final markers = _sites.where((s) => s.lat != null && s.lon != null).map((
      s,
    ) {
      final isSelected = _selectedSite?.id == s.id;
      final color = _statusColor(s);

      return Marker(
        width: 36,
        height: 36,
        point: LatLng(s.lat!, s.lon!),
        child: GestureDetector(
          onTap: () {
            setState(() {
              _selectedSite = s;
            });
          },
          child: AnimatedScale(
            scale: isSelected ? 1.2 : 1.0,
            duration: const Duration(milliseconds: 150),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? Colors.orange.shade700 : color,
                boxShadow: const [
                  BoxShadow(
                    blurRadius: 4,
                    offset: Offset(0, 2),
                    color: Color(0x55000000),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(4),
              child: const Icon(
                Icons.local_parking,
                size: 18,
                color: Colors.white,
              ),
            ),
          ),
        ),
      );
    }).toList();

    return Scaffold(
      key: _scaffoldKey,

      appBar: AppBar(
        title: const Text('MobiData BW in Flutter'),
        actions: [
          IconButton(
            icon: Icon(_showFilterBar ? Icons.close : Icons.filter_list),
            tooltip: _showFilterBar ? 'Filter verstecken' : 'Filter anzeigen',
            onPressed: () {
              setState(() {
                _showFilterBar = !_showFilterBar;
              });
            },
          ),
        ],
      ),

      drawer: _buildMainDrawer(context),

      // karte
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center,
              backgroundColor: Colors.grey.shade900,
              initialZoom: _zoom,
              onPositionChanged: (pos, hasGesture) {
                _center = pos.center ?? _center;
                _zoom = pos.zoom ?? _zoom;

                if (hasGesture == true && _autoLoadOnMove) {
                  _onMapMovedDebounced();
                }
              },
            ),

            // layer mit markern
            children: [
              TileLayer(
                urlTemplate: isDark
                    ? 'https://cartodb-basemaps-{s}.global.ssl.fastly.net/dark_all/{z}/{x}/{y}.png'
                    : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', // standard OSM
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'org.codevember.mobidata_bw_flutter',
              ),
              MarkerLayer(markers: markers),
            ],
          ),

          // attribution widget
          MapAttributionWidget(isDarkMode: isDark),

          // filter
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            top: _showFilterBar
                ? 8
                : -100, // kToolbarHeight rausfahren nach oben
            left: 8,
            right: 8,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: _showFilterBar ? 1.0 : 0.0,
              child: Card(
                elevation: 6,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: FilterBar(
                    showOnlyAvailable: _showOnlyAvailable,
                    onChangeAvailable: (val) {
                      setState(() => _showOnlyAvailable = val);
                      _loadParking();
                    },
                  ),
                ),
              ),
            ),
          ),

          /*
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: FilterBar(
              showOnlyAvailable: _showOnlyAvailable,
              onChangeAvailable: (val) {
                setState(() => _showOnlyAvailable = val);
                _loadParking();
              },
            ),
          ),
          */

          // overlay zum laden
          if (_loading)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x11000000),
                child: Center(
                  child: SpinKitFadingCircle(
                      size: 48, color: Color.fromRGBO(255, 102, 255, 255)),
                ),
              ),
            ),

          // legende
          Positioned(
            bottom: 8,
            left: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: const [
                  Icon(Icons.local_parking, color: Colors.green, size: 18),
                  SizedBox(width: 4),
                  Text('frei'),
                  SizedBox(width: 12),
                  Icon(Icons.local_parking, color: Colors.red, size: 18),
                  SizedBox(width: 4),
                  Text('belegt'),
                  SizedBox(width: 12),
                  Icon(Icons.local_parking, color: Colors.blue, size: 18),
                  SizedBox(width: 4),
                  Text('unbekannt'),
                ],
              ),
            ),
          ),

          // fehlerbox
          if (_error != null)
            Positioned(
              left: 12,
              right: 12,
              bottom: 140,
              child: Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text('Fehler: $_error'),
                ),
              ),
            ),

          // info fenster
          if (_selectedSite != null)
            Positioned(
              left: 12,
              right: 12,
              bottom: 24,
              child: ParkingInfoCard(
                site: _selectedSite!,
                onClose: () {
                  setState(() {
                    _selectedSite = null;
                  });
                },
              ),
            ),
        ],
      ),
    );
  }

  ////////////////////////////////////////
  /// KATEGORIEN LISTE
  ////////////////////////////////////////

  Widget _buildCategoryTile(DatasetCategory cat, String label) {
    final isSelected = _selectedCategory == cat;
    final isEnabled = cat == DatasetCategory.parking;

    IconData icon;
    switch (cat) {
      case DatasetCategory.parking:
        icon = Icons.local_parking;
        break;
      case DatasetCategory.carsharing:
        icon = Icons.directions_car;
        break;
      case DatasetCategory.bikesharing:
        icon = Icons.pedal_bike;
        break;
      case DatasetCategory.scooters:
        icon = Icons.electric_scooter;
        break;
      case DatasetCategory.transit:
        icon = Icons.directions_bus;
        break;
      case DatasetCategory.charging:
        icon = Icons.ev_station;
        break;
      case DatasetCategory.construction:
        icon = Icons.construction;
        break;
      case DatasetCategory.bicycleNetwork:
        icon = Icons.directions_bike;
        break;
    }

    return ListTile(
      leading: Icon(icon, color: isEnabled ? null : Colors.grey),
      title: Text(
        label,
        style: TextStyle(color: isEnabled ? null : Colors.grey),
      ),
      selected: isSelected,
      enabled: isEnabled,
      onTap: !isEnabled
          ? null
          : () {
              Navigator.of(context).pop();
              setState(() {
                _selectedCategory = cat;
                // aktuell lädt _loadParking() nur parkplätze
              });
              _loadParking();
            },
    );
  }

  ////////////////////////////////////////
  /// DRAWER
  ////////////////////////////////////////

  Widget _buildMainDrawer(BuildContext context) {
    final theme = Theme.of(context);

    // Kategorien als Anzeige-Namen
    final items = <DatasetCategory, String>{
      DatasetCategory.parking: 'Parkplätze',
      DatasetCategory.carsharing: 'Carsharing',
      DatasetCategory.bikesharing: 'Bikesharing',
      DatasetCategory.scooters: 'E-Scooter',
      DatasetCategory.transit: 'ÖPNV',
      DatasetCategory.charging: 'Ladeinfrastruktur',
      DatasetCategory.construction: 'Baustellen',
      DatasetCategory.bicycleNetwork: 'Radnetz',
    };

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.9),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MobiData BW in Flutter',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '(Inoffiziell)',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),

            // hinweis
            if (_showDrawerHint)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: DrawerHint(
                  onClose: () {
                    _markDrawerHintAsShown();
                  },
                ),
              ),

            // kategorien
            Expanded(
              child: ListView(
                children: [
                  for (final entry in items.entries)
                    _buildCategoryTile(entry.key, entry.value),
                ],
              ),
            ),

            const Divider(height: 1),

            // einstellungen
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Einstellungen'),
              onTap: () {
                Navigator.of(context).pop(); // Drawer schließen
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => SettingsSheet(
                    autoLoadOnMove: _autoLoadOnMove,
                    openDrawerOnStart: _openDrawerOnStart,
                    onChangeAutoLoadOnMove: (val) {
                      _setAutoLoadOnMove(val);
                    },
                    onChangeOpenDrawerOnStart: (val) {
                      _setOpenDrawerOnStart(val);
                    },
                    appThemeSetting: widget.appThemeSetting,
                    onChangeTheme: widget.onChangeAppTheme,
                  ),
                );
              },
            ),

            // impressum + lizenzen
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Impressum & Lizenzen'),
              onTap: () {
                Navigator.of(context).pop();
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => const ImpressumSheet(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
