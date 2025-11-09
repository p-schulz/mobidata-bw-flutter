import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/mobidata_api.dart';
import '../models/parking_site.dart';

import '../models/app_theme_settings.dart';

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


////////////////////////////////////////
/// HAUPTSCREEN
////////////////////////////////////////

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
  final MobiDataApi _api = MobiDataApi();

  LatLng _center = const LatLng(48.5216, 9.0576);
  double _zoom = 8.0;

  bool _loading = false;
  String? _error;
  Timer? _debounce;

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
/*
  Future<void> _markDrawerHintAsShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('drawerHintShown', true);
  }
*/
  



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
      final allSites = await _api.fetchParkingSites();
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
    final markers = _sites
        .where((s) => s.lat != null && s.lon != null)
        .map((s) {
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
                    ? 'https://{s}.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png' // Beispiel dunkel/kontrastreich
                    : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',       // Standard
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'com.example.mobidata_bw_flutter',
              ),
              MarkerLayer(markers: markers),
            ],
          ),

          // filter
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: _FilterBar(
              showOnlyAvailable: _showOnlyAvailable,
              onChangeAvailable: (val) {
                setState(() => _showOnlyAvailable = val);
                _loadParking();
              },
            ),
          ),

          // overlay zum laden
          if (_loading)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x11000000),
                child: Center(
                  child: SpinKitFadingCircle(
                    size: 48,
                    color: Colors.white,
                  ),
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
              child: _ParkingInfoCard(
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
      leading: Icon(
        icon,
        color: isEnabled ? null : Colors.grey,
      ),
      title: Text(
        label,
        style: TextStyle(
          color: isEnabled ? null : Colors.grey,
        ),
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
                    style: theme.textTheme.titleLarge
                        ?.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '(Inoffiziell)',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: Colors.white70),
                  ),
                ],
              ),
            ),

            // hinweis
            if (_showDrawerHint)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: _DrawerHint(
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
                  builder: (_) => _SettingsSheet(
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
            
            /*
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Einstellungen'),
              onTap: () {
                Navigator.of(context).pop();
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => const _SettingsSheet(),
                );
              },
            ),
            */

            // impressum + lizenzen
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Impressum & Lizenzen'),
              onTap: () {
                Navigator.of(context).pop();
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => const _ImpressumSheet(),
                );
              },
            ),

          ],
        ),
      ),
    );
  }

}


////////////////////////////////////////
/// DRAWER HINWEIS
////////////////////////////////////////
class _DrawerHint extends StatelessWidget {
  final VoidCallback onClose;

  const _DrawerHint({required this.onClose});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color: Colors.amber.shade50,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.swipe_right_alt,
                color: theme.colorScheme.primary, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Wähle hier die Datensatzkategorie.\n'
                    'Aktuell ist nur „Parkplätze“ aktiv.',
                style: theme.textTheme.bodySmall,
              ),
            ),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(Icons.close, size: 18),
              onPressed: onClose,
              tooltip: 'Hinweis ausblenden',
            ),
          ],
        ),
      ),
    );
  }
}


////////////////////////////////////////
/// EINSTELLUNGEN
////////////////////////////////////////

class _SettingsSheet extends StatefulWidget {
  final bool autoLoadOnMove;
  final bool openDrawerOnStart;
  final ValueChanged<bool> onChangeAutoLoadOnMove;
  final ValueChanged<bool> onChangeOpenDrawerOnStart;

  final AppThemeSetting appThemeSetting;
  final ValueChanged<AppThemeSetting> onChangeTheme; // NEU

  const _SettingsSheet({
    required this.autoLoadOnMove,
    required this.openDrawerOnStart,
    required this.onChangeAutoLoadOnMove,
    required this.onChangeOpenDrawerOnStart,
    required this.appThemeSetting,
    required this.onChangeTheme,
  });

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  late bool _autoLoadOnMove;
  late bool _openDrawerOnStart;
  late AppThemeSetting _appThemeSetting;

  @override
  void initState() {
    super.initState();
    _autoLoadOnMove = widget.autoLoadOnMove;
    _openDrawerOnStart = widget.openDrawerOnStart;
    _appThemeSetting = widget.appThemeSetting;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.settings_outlined,
                      color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Einstellungen',
                    style: theme.textTheme.titleLarge,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              //const SizedBox(height: 16),
              Text(
                'Darstellung',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 4),

              RadioListTile<AppThemeSetting>(
                contentPadding: EdgeInsets.zero,
                title: const Text('Systemeinstellung verwenden'),
                value: AppThemeSetting.system,
                groupValue: _appThemeSetting,
                onChanged: (val) {
                  if (val == null) return;
                  setState(() => _appThemeSetting = val);
                  widget.onChangeTheme(val);
                },
              ),
              RadioListTile<AppThemeSetting>(
                contentPadding: EdgeInsets.zero,
                title: const Text('Helles Design'),
                value: AppThemeSetting.light,
                groupValue: _appThemeSetting,
                onChanged: (val) {
                  if (val == null) return;
                  setState(() => _appThemeSetting = val);
                  widget.onChangeTheme(val);
                },
              ),
              RadioListTile<AppThemeSetting>(
                contentPadding: EdgeInsets.zero,
                title: const Text('Dunkles Design'),
                value: AppThemeSetting.dark,
                groupValue: _appThemeSetting,
                onChanged: (val) {
                  if (val == null) return;
                  setState(() => _appThemeSetting = val);
                  widget.onChangeTheme(val);
                },
              ),
              
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                    'Parkplätze beim Kartenverschieben automatisch nachladen'),
                subtitle: const Text(
                    'Deaktivieren, wenn nur manuell über den Refresh-Button geladen werden soll.'),
                value: _autoLoadOnMove,
                onChanged: (val) {
                  setState(() => _autoLoadOnMove = val);
                  widget.onChangeAutoLoadOnMove(val); // an HomeScreen weitergeben
                },
              ),

              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                    'Drawer beim App-Start automatisch öffnen'),
                value: _openDrawerOnStart,
                onChanged: (val) {
                  setState(() => _openDrawerOnStart = val);
                  widget.onChangeOpenDrawerOnStart(val);
                },
              ),

              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Schließen'),
                ),
              ),
            
            ],
          ),
        ),
      ),
    );
  }
}


////////////////////////////////////////
/// IPRESSUM
////////////////////////////////////////

class _ImpressumSheet extends StatelessWidget {
  const _ImpressumSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Impressum & Lizenzen',
                    style: theme.textTheme.titleLarge,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Text(
                'Hinweis',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              const Text(
                'Diese App ist ein inoffizielles Projekt des Codevember e.V '
                    'und steht in keinem offiziellen Zusammenhang mit der '
                    'NVBW Nahverkehrsgesellschaft Baden-Württemberg mbH.',
              ),

              const SizedBox(height: 16),
              Text(
                'Rechtliches und Lizenzen',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              const Text(
                '• MobiData BW – zentrale Daten- und Serviceplattform für Mobilität in Baden-Württemberg.\n'
                    '• Bereitstellung von Parkdaten (u. a. ParkAPI / DATEX II), '
                    'teilweise unter der Datenlizenz Deutschland – Namensnennung 2.0 (DL-DE-BY 2.0).',
              ),

              const SizedBox(height: 16),
              Text(
                'Open-Source-Komponenten',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              const Text(
                '• Flutter (Google)\n'
                    '• flutter_map + OpenStreetMap-Tiles\n'
                    '• Dio, Geolocator, flutter_spinkit\n'
                    'Lizenzdetails siehe „Flutter Lizenzen anzeigen“.',
              ),

              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () {
                    showLicensePage(
                      context: context,
                      applicationName: 'MobiData BW in Flutter',
                      applicationVersion: '0.1.0',
                    );
                  },
                  icon: const Icon(Icons.article_outlined),
                  label: const Text('Flutter-Lizenzen anzeigen'),
                ),
              ),

              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Schließen'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


////////////////////////////////////////
/// FILTER LEISTE
////////////////////////////////////////

class _FilterBar extends StatelessWidget {
  final bool showOnlyAvailable;
  final ValueChanged<bool> onChangeAvailable;

  const _FilterBar({
    required this.showOnlyAvailable,
    required this.onChangeAvailable,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      color: Colors.white.withOpacity(0.9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                FilterChip(
                  label: const Text('Freie Parkplätze'),
                  selected: showOnlyAvailable,
                  onSelected: onChangeAvailable,
                  selectedColor: Colors.green.shade200,
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Filter zurücksetzen',
              onPressed: () {
                onChangeAvailable(false);
              },
            ),
          ],
        ),
      ),
    );
  }
}


////////////////////////////////////////
/// PARKPLATZ INFO
////////////////////////////////////////

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
            if (site.availableSpaces != null) Text('Kapazität: ${site.availableSpaces}'),
            if (site.status != null) Text('Status: ${site.status}'),
            if (site.roadName != null) Text('Adresse: ${site.roadName}'),
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


////////////////////////////////////////
/// PARKPLATZ DETAILS
////////////////////////////////////////

class _ParkingInfoCard extends StatelessWidget {
  final ParkingSite site;
  final VoidCallback onClose;

  const _ParkingInfoCard({
    required this.site,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.local_parking, size: 28),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    site.name,
                    style: theme.textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      if (site.availableSpaces != null)
                        Text('Kapazität: ${site.availableSpaces}',
                            style: theme.textTheme.bodySmall),
                      if (site.status != null)
                        Text('Status: ${site.status}',
                            style: theme.textTheme.bodySmall),
                      if (site.lat != null && site.lon != null)
                        Text(
                          '${site.lat!.toStringAsFixed(4)}, ${site.lon!.toStringAsFixed(4)}',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: Colors.grey[600]),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            TextButton(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  builder: (_) => _ParkingSheet(site: site),
                );
              },
              child: const Text('Details'),
            ),

            const SizedBox(width: 8),
            IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close),
              tooltip: 'Schließen',
            ),
          ],
        ),
      ),
    );
  }
}
