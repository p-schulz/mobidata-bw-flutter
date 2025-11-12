import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/park_api_service.dart';
import '../services/sharing_api_service.dart';

import '../models/categories.dart';
import '../models/app_theme_setting.dart';
import '../models/parking_site.dart';
import '../models/parking_spot.dart';
import '../models/carsharing_offer.dart';
import '../models/bikesharing_station.dart';
import '../models/scooter_vehicle.dart';
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
  final SharingApiService _sharingApiService = SharingApiService();

  LatLng _center = const LatLng(48.5216, 9.0576);
  double _zoom = 13.0;
  bool _mapReady = false;

  bool _loading = false;
  String? _error;
  Timer? _debounce;
  bool _showFilterBar = true;

  DatasetCategory _selectedCategory = DatasetCategory.parking;

  // parkplätze
  List<ParkingSite> _parkingSites = [];
  List<ParkingSpot> _parkingSpots = [];
  ParkingSite? _selectedSite;
  ParkingSpot? _selectedSpot;
  bool _showOnlyAvailable = false;
  bool _filterOnlyFreeParking = false;

  // carsharing
  List<CarsharingOffer> _carsharingOffers = [];
  bool _filterOnlyWithCars = false;
  CarsharingOffer? _selectedCarsharingOffer;

  // bikesharing
  List<BikesharingStation> _bikesharingStations = [];
  BikesharingStation? _selectedBikesharingStation;

  // scooter
  List<ScooterVehicle> _scooterVehicles = [];
  ScooterVehicle? _selectedScooterVehicle;

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
    _loadDataForCurrentCategory();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  // einstellungen laden
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
      _moveMapIfReady();
    } catch (_) {
      // ignorieren
    }
  }

  void _moveMapIfReady() {
    if (!_mapReady) return;
    _mapController.move(_center, _zoom);
  }

  // live karten ausschnitt
  LatLngBounds _currentBounds() {
    if (!_mapReady) {
      return LatLngBounds(
        LatLng(_center.latitude - 0.05, _center.longitude - 0.05),
        LatLng(_center.latitude + 0.05, _center.longitude + 0.05),
      );
    }

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
      switch (_selectedCategory) {
        case DatasetCategory.parking:
          _loadParking();
          break;
        case DatasetCategory.carsharing:
        case DatasetCategory.bikesharing:
        case DatasetCategory.scooters:
          _loadDataForCurrentCategory();
          break;
        default:
          break;
      }
    });
  }

  Future<void> _loadDataForCurrentCategory() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final bounds = _currentBounds();

      switch (_selectedCategory) {
        case DatasetCategory.parking:
          final sites = await _parkApiService.fetchParkingSites();
          final spots = await _parkApiService.fetchParkingSpots();
          final filteredSites = _filterParkingSitesWithinBounds(sites, bounds);
          final filteredSpots = _filterParkingSpotsWithinBounds(spots, bounds);
          setState(() {
            _parkingSites = filteredSites;
            _parkingSpots = filteredSpots;
            _carsharingOffers = [];
            _bikesharingStations = [];
            _scooterVehicles = [];
            _selectedCarsharingOffer = null;
            _selectedBikesharingStation = null;
            _selectedScooterVehicle = null;
            _selectedSpot = null;
          });
          break;

        case DatasetCategory.carsharing:
          final previousCarId = _selectedCarsharingOffer?.id;
          final all = await _sharingApiService.fetchCarsharingOffers(
            bounds: bounds,
          );
          final filtered = all.where((o) {
            return o.lat >= bounds.south &&
                o.lat <= bounds.north &&
                o.lon >= bounds.west &&
                o.lon <= bounds.east;
          }).toList();
          CarsharingOffer? preservedCar;
          if (previousCarId != null) {
            for (final offer in filtered) {
              if (offer.id == previousCarId) {
                preservedCar = offer;
                break;
              }
            }
          }
          setState(() {
            _carsharingOffers = filtered;
            _parkingSites = [];
            _parkingSpots = [];
            _bikesharingStations = [];
            _scooterVehicles = [];
            _selectedSite = null;
            _selectedSpot = null;
            _selectedCarsharingOffer = preservedCar;
            _selectedBikesharingStation = null;
            _selectedScooterVehicle = null;
          });
          break;
        case DatasetCategory.bikesharing:
          final previousBikeId = _selectedBikesharingStation?.id;
          final allBikes = await _sharingApiService.fetchBikesharingStations(
            bounds: bounds,
          );
          final filteredBikes = allBikes.where((o) {
            return o.lat >= bounds.south &&
                o.lat <= bounds.north &&
                o.lon >= bounds.west &&
                o.lon <= bounds.east;
          }).toList();
          BikesharingStation? preservedBike;
          if (previousBikeId != null) {
            for (final station in filteredBikes) {
              if (station.id == previousBikeId) {
                preservedBike = station;
                break;
              }
            }
          }
          setState(() {
            _bikesharingStations = filteredBikes;
            _carsharingOffers = [];
            _parkingSites = [];
            _parkingSpots = [];
            _scooterVehicles = [];
            _selectedSite = null;
            _selectedSpot = null;
            _selectedCarsharingOffer = null;
            _selectedBikesharingStation = preservedBike;
            _selectedScooterVehicle = null;
          });
          break;
        case DatasetCategory.scooters:
          final previousScooterId = _selectedScooterVehicle?.id;
          final allScooters = await _sharingApiService.fetchScooterVehicles(
            bounds: bounds,
          );
          final filteredScooters = allScooters.where((o) {
            return o.lat >= bounds.south &&
                o.lat <= bounds.north &&
                o.lon >= bounds.west &&
                o.lon <= bounds.east;
          }).toList();
          ScooterVehicle? preservedScooter;
          if (previousScooterId != null) {
            for (final scooter in filteredScooters) {
              if (scooter.id == previousScooterId) {
                preservedScooter = scooter;
                break;
              }
            }
          }
          setState(() {
            _scooterVehicles = filteredScooters;
            _bikesharingStations = [];
            _carsharingOffers = [];
            _parkingSites = [];
            _parkingSpots = [];
            _selectedSite = null;
            _selectedSpot = null;
            _selectedCarsharingOffer = null;
            _selectedBikesharingStation = null;
            _selectedScooterVehicle = preservedScooter;
          });
          break;
        case DatasetCategory.transit:
          break;
        case DatasetCategory.charging:
          break;
        case DatasetCategory.construction:
          break;
        case DatasetCategory.bicycleNetwork:
          break;
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _loadParking() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // daten abrufen
      final allSites = await _parkApiService.fetchParkingSites();
      final allSpots = await _parkApiService.fetchParkingSpots();

      // kartenbegrenzung
      final b = _currentBounds();

      final filteredSites = _filterParkingSitesWithinBounds(allSites, b);
      final filteredSpots = _filterParkingSpotsWithinBounds(allSpots, b);

      setState(() {
        _parkingSites = filteredSites;
        _parkingSpots = filteredSpots;
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

  List<ParkingSite> _filterParkingSitesWithinBounds(
    List<ParkingSite> sites,
    LatLngBounds bounds,
  ) {
    return sites.where((s) {
      final lat = s.lat;
      final lon = s.lon;
      if (lat == null || lon == null) return false;

      if (!_isWithinBounds(lat, lon, bounds)) {
        return false;
      }

      if (_showOnlyAvailable &&
          !(s.availableSpaces != null && s.availableSpaces! > 0)) {
        return false;
      }

      if (_filterOnlyFreeParking) {
        if (s.availableSpaces == null || s.availableSpaces! <= 0) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  List<ParkingSpot> _filterParkingSpotsWithinBounds(
    List<ParkingSpot> spots,
    LatLngBounds bounds,
  ) {
    return spots.where((spot) {
      if (!_isWithinBounds(spot.lat, spot.lon, bounds)) {
        return false;
      }

      if ((_showOnlyAvailable || _filterOnlyFreeParking) &&
          !_isSpotAvailable(spot)) {
        return false;
      }

      return true;
    }).toList();
  }

  bool _isSpotAvailable(ParkingSpot spot) =>
      (spot.realtimeStatus ?? '').toUpperCase() == 'AVAILABLE';

  bool _isWithinBounds(double lat, double lon, LatLngBounds bounds) =>
      lat >= bounds.south &&
      lat <= bounds.north &&
      lon >= bounds.west &&
      lon <= bounds.east;

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

  Color _parkingSpotColor(ParkingSpot spot) {
    switch ((spot.realtimeStatus ?? '').toUpperCase()) {
      case 'AVAILABLE':
        return Colors.green.shade700;
      case 'OCCUPIED':
      case 'UNAVAILABLE':
        return Colors.red.shade700;
      default:
        return Colors.blueGrey.shade700;
    }
  }

  void _showParkingInfo(ParkingSite s) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          runSpacing: 8,
          children: [
            Text(s.name ?? 'Parkplatz',
                style: Theme.of(context).textTheme.titleLarge),
            if (s.totalSpaces != null)
              Text('Stellplätze gesamt: ${s.totalSpaces}'),
            if (s.availableSpaces != null) Text('frei: ${s.availableSpaces}'),
            if (s.isOpenNow != null)
              Text(s.isOpenNow! ? 'Geöffnet' : 'Geschlossen'),
            if (s.lastUpdate != null) Text('Stand: ${s.lastUpdate}'),
          ],
        ),
      ),
    );
  }

  void _showParkingSpotDetails(ParkingSpot spot) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(spot.name, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              if (spot.address != null) Text('Adresse: ${spot.address}'),
              if (spot.realtimeStatus != null)
                Text('Status: ${spot.realtimeStatus}'),
              Text('Echtzeitdaten: ${spot.hasRealtimeData ? 'ja' : 'nein'}'),
              if (spot.staticDataUpdatedAt != null)
                Text('Stand: ${spot.staticDataUpdatedAt}'),
              if (spot.realtimeDataUpdatedAt != null)
                Text('Live: ${spot.realtimeDataUpdatedAt}'),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
                label: const Text('Schließen'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCarsharingDetails(CarsharingOffer offer) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(offer.name, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text('Anbieter: ${offer.provider}'),
              Text('Fahrzeugtyp: ${offer.vehicleType}'),
              Text('Verfügbare Fahrzeuge: ${offer.availableVehicles}'),
              Text(
                  'Vermietung möglich: ${offer.isRentingAllowed ? 'ja' : 'nein'}'),
              Text(
                  'Position: ${offer.lat.toStringAsFixed(5)}, ${offer.lon.toStringAsFixed(5)}'),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  label: const Text('Schließen'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBikesharingDetails(BikesharingStation station) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(station.name, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text('Anbieter: ${station.provider}'),
              Text('Verfügbare Räder: ${station.availableVehicles}'),
              Text(
                  'Verleih möglich: ${station.isRentingAllowed ? 'ja' : 'nein'}'),
              Text(
                  'Position: ${station.lat.toStringAsFixed(5)}, ${station.lon.toStringAsFixed(5)}'),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  label: const Text('Schließen'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showScooterDetails(ScooterVehicle vehicle) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(vehicle.vehicleType,
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text('Anbieter: ${vehicle.provider}'),
              if (vehicle.batteryPercent != null)
                Text(
                    'Akku: ${(vehicle.batteryPercent! * 100).round()}% (${vehicle.rangeMeters?.toStringAsFixed(0) ?? '?'} m)'),
              Text('Reserviert: ${vehicle.isReserved ? 'ja' : 'nein'}'),
              Text('Aktiv: ${vehicle.isDisabled ? 'nein' : 'ja'}'),
              Text(
                  'Position: ${vehicle.lat.toStringAsFixed(5)}, ${vehicle.lon.toStringAsFixed(5)}'),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  label: const Text('Schließen'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Marker> _buildMarkersForCategory() {
    switch (_selectedCategory) {
      case DatasetCategory.parking:
        return _buildParkingMarkers();
      case DatasetCategory.carsharing:
        return _buildCarsharingMarkers();
      case DatasetCategory.bikesharing:
        return _buildBikesharingMarkers();
      case DatasetCategory.scooters:
        return _buildScooterMarkers();
      case DatasetCategory.transit:
        return List<Marker>.empty();
      case DatasetCategory.charging:
        return List<Marker>.empty();
      case DatasetCategory.construction:
        return List<Marker>.empty();
      case DatasetCategory.bicycleNetwork:
        return List<Marker>.empty();
    }
  }

  List<Marker> _buildParkingMarkers() {
    final siteMarkers = _parkingSites
        .map((s) {
          final lat = s.lat, lon = s.lon;
          if (lat == null || lon == null) return null;

          final isSelected = _selectedSite?.id == s.id;
          final color = _statusColor(s);

          return Marker(
            width: 36,
            height: 36,
            point: LatLng(lat, lon),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  final alreadySelected = _selectedSite?.id == s.id;
                  _selectedSite = alreadySelected ? null : s;
                  _selectedSpot = null;
                  _selectedCarsharingOffer = null;
                  _selectedBikesharingStation = null;
                  _selectedScooterVehicle = null;
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
        })
        .whereType<Marker>()
        .toList();

    final spotMarkers = _parkingSpots.map((spot) {
      final isSelected = _selectedSpot?.id == spot.id;
      final color = _parkingSpotColor(spot);
      return Marker(
        width: 32,
        height: 32,
        point: LatLng(spot.lat, spot.lon),
        child: GestureDetector(
          onTap: () {
            setState(() {
              final alreadySelected = _selectedSpot?.id == spot.id;
              _selectedSpot = alreadySelected ? null : spot;
              _selectedSite = null;
              _selectedCarsharingOffer = null;
              _selectedBikesharingStation = null;
              _selectedScooterVehicle = null;
            });
          },
          child: Tooltip(
            message: spot.realtimeStatus != null
                ? '${spot.name} (${spot.realtimeStatus})'
                : spot.name,
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
                      color: Color(0x33000000),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(5),
                child: const Icon(
                  Icons.push_pin,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      );
    }).toList();

    return [...siteMarkers, ...spotMarkers];
  }

  List<Marker> _buildCarsharingMarkers() {
    return _carsharingOffers.map((o) {
      final point = LatLng(o.lat, o.lon);
      final color = o.availableVehicles > 0
          ? Colors.green.shade600
          : Colors.grey.shade600;
      final isSelected = _selectedCarsharingOffer?.id == o.id;

      return Marker(
        width: 36,
        height: 36,
        point: point,
        child: GestureDetector(
          onTap: () {
            setState(() {
              final alreadySelected = _selectedCarsharingOffer?.id == o.id;
              _selectedCarsharingOffer = alreadySelected ? null : o;
              _selectedBikesharingStation = null;
              _selectedScooterVehicle = null;
              _selectedSite = null;
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
                    color: Color(0x44000000),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(6),
              child: const Icon(
                Icons.directions_car,
                size: 18,
                color: Colors.white,
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  List<Marker> _buildBikesharingMarkers() {
    return _bikesharingStations.map((station) {
      final point = LatLng(station.lat, station.lon);
      final color =
          station.availableVehicles > 0 ? Colors.green.shade600 : Colors.red;
      final isSelected = _selectedBikesharingStation?.id == station.id;

      return Marker(
        width: 34,
        height: 34,
        point: point,
        child: GestureDetector(
          onTap: () {
            setState(() {
              _selectedBikesharingStation = isSelected ? null : station;
              _selectedCarsharingOffer = null;
              _selectedScooterVehicle = null;
              _selectedSite = null;
            });
          },
          child: Tooltip(
            message:
                '${station.name} (${station.availableVehicles} Bikes verfügbar)',
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
                      color: Color(0x33000000),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(6),
                child: const Icon(
                  Icons.pedal_bike,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  List<Marker> _buildScooterMarkers() {
    return _scooterVehicles.map((vehicle) {
      final point = LatLng(vehicle.lat, vehicle.lon);
      Color color;
      if (vehicle.isDisabled) {
        color = Colors.grey;
      } else if ((vehicle.batteryPercent ?? 1) < 0.2) {
        color = Colors.orange;
      } else {
        color = Colors.lightGreen;
      }
      final batteryText = vehicle.batteryPercent != null
          ? ' - ${(vehicle.batteryPercent! * 100).round()}%'
          : '';
      final isSelected = _selectedScooterVehicle?.id == vehicle.id;

      return Marker(
        width: 34,
        height: 34,
        point: point,
        child: GestureDetector(
          onTap: () {
            setState(() {
              _selectedScooterVehicle = isSelected ? null : vehicle;
              _selectedCarsharingOffer = null;
              _selectedBikesharingStation = null;
              _selectedSite = null;
            });
          },
          child: Tooltip(
            message: '${vehicle.vehicleType}$batteryText',
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
                      color: Color(0x33000000),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(6),
                child: const Icon(
                  Icons.electric_scooter,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget? _buildActiveInfoCard() {
    if (_selectedSite != null) {
      return ParkingInfoCard(
        site: _selectedSite!,
        onClose: () {
          setState(() {
            _selectedSite = null;
          });
        },
      );
    }

    if (_selectedSpot != null) {
      final spot = _selectedSpot!;
      return _buildSharingInfoCard(
        icon: Icons.push_pin,
        title: spot.name,
        details: [
          if (spot.realtimeStatus != null)
            Text('Status: ${spot.realtimeStatus}'),
          if (spot.address != null) Text(spot.address!),
          Text(
              '${spot.lat.toStringAsFixed(4)}, ${spot.lon.toStringAsFixed(4)}'),
        ],
        onDetails: () => _showParkingSpotDetails(spot),
        onClose: () {
          setState(() {
            _selectedSpot = null;
          });
        },
      );
    }

    if (_selectedCarsharingOffer != null) {
      final offer = _selectedCarsharingOffer!;
      return _buildSharingInfoCard(
        icon: Icons.directions_car,
        title: offer.name,
        details: [
          Text('Anbieter: ${offer.provider}'),
          Text('Verfügbar: ${offer.availableVehicles}'),
          Text('Typ: ${offer.vehicleType}'),
          Text(
              '${offer.lat.toStringAsFixed(4)}, ${offer.lon.toStringAsFixed(4)}'),
        ],
        onDetails: () => _showCarsharingDetails(offer),
        onClose: () {
          setState(() {
            _selectedCarsharingOffer = null;
          });
        },
      );
    }

    if (_selectedBikesharingStation != null) {
      final station = _selectedBikesharingStation!;
      return _buildSharingInfoCard(
        icon: Icons.pedal_bike,
        title: station.name,
        details: [
          Text('Anbieter: ${station.provider}'),
          Text('Verfügbar: ${station.availableVehicles}'),
          Text(
              '${station.lat.toStringAsFixed(4)}, ${station.lon.toStringAsFixed(4)}'),
        ],
        onDetails: () => _showBikesharingDetails(station),
        onClose: () {
          setState(() {
            _selectedBikesharingStation = null;
          });
        },
      );
    }

    if (_selectedScooterVehicle != null) {
      final scooter = _selectedScooterVehicle!;
      final battery = scooter.batteryPercent != null
          ? '${(scooter.batteryPercent! * 100).round()}%'
          : 'unbekannt';
      return _buildSharingInfoCard(
        icon: Icons.electric_scooter,
        title: scooter.vehicleType,
        details: [
          Text('Anbieter: ${scooter.provider}'),
          Text('Akku: $battery'),
          Text(
              '${scooter.lat.toStringAsFixed(4)}, ${scooter.lon.toStringAsFixed(4)}'),
        ],
        onDetails: () => _showScooterDetails(scooter),
        onClose: () {
          setState(() {
            _selectedScooterVehicle = null;
          });
        },
      );
    }

    return null;
  }

  Widget _buildSharingInfoCard({
    required IconData icon,
    required String title,
    required List<Widget> details,
    required VoidCallback onClose,
    VoidCallback? onDetails,
  }) {
    final theme = Theme.of(context);
    final detailStyle =
        theme.textTheme.bodySmall ?? const TextStyle(fontSize: 12);
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 28),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: details
                        .map((w) => DefaultTextStyle(
                              style: detailStyle,
                              child: w,
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
            if (onDetails != null)
              TextButton(
                onPressed: onDetails,
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

  void _applyFiltersForCurrentCategory() {
    final bounds = _currentBounds();

    switch (_selectedCategory) {
      case DatasetCategory.parking:
        final filteredSites = _filterParkingSitesWithinBounds(
          _parkingSites,
          bounds,
        );
        final filteredSpots = _filterParkingSpotsWithinBounds(
          _parkingSpots,
          bounds,
        );
        setState(() {
          _parkingSites = filteredSites;
          _parkingSpots = filteredSpots;
        });
        break;

      case DatasetCategory.carsharing:
        final all = _carsharingOffers;
        final filtered = all.where((o) {
          final inBox = o.lat >= bounds.south &&
              o.lat <= bounds.north &&
              o.lon >= bounds.west &&
              o.lon <= bounds.east;
          if (!inBox) return false;
          if (_filterOnlyWithCars) {
            return o.availableVehicles > 0;
          }
          return true;
        }).toList();
        setState(() => _carsharingOffers = filtered);
        break;
      default:
        break;
    }
  }

  ////////////////////////////////////////
  /// MAIN SCREEN
  ////////////////////////////////////////
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final markers =
        _parkingSites.where((s) => s.lat != null && s.lon != null).map((
      s,
    ) {
      final isSelected = _selectedSite?.id == s.id;
      final color = _statusColor(s);
    }).toList();
    final infoCard = _buildActiveInfoCard();

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
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.drag |
                    InteractiveFlag.pinchZoom |
                    InteractiveFlag.doubleTapZoom |
                    InteractiveFlag.scrollWheelZoom,
              ),
              onMapReady: () {
                setState(() {
                  _mapReady = true;
                });
                _moveMapIfReady();
                _loadDataForCurrentCategory();
              },
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
              //MarkerLayer(markers: markers),
              MarkerLayer(
                markers: _buildMarkersForCategory(),
              ),
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
                    category: _selectedCategory,
                    showOnlyFreeParking: _filterOnlyFreeParking,
                    onToggleOnlyFreeParking: (val) {
                      setState(() => _filterOnlyFreeParking = val);
                      _applyFiltersForCurrentCategory();
                    },
                    showOnlyWithCars: _filterOnlyWithCars,
                    onToggleOnlyWithCars: (val) {
                      setState(() => _filterOnlyWithCars = val);
                      _applyFiltersForCurrentCategory();
                    },
                  ),
                ),
              ),
            ),
          ),

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
            left: 8,
            bottom: 80,
            child: _buildLegendForCategory(),
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

          if (infoCard != null)
            Positioned(
              left: 12,
              right: 12,
              bottom: 24,
              child: infoCard,
            ),
        ],
      ),
    );
  }

  ////////////////////////////////////////
  /// KARTEN LEGENDE
  ////////////////////////////////////////

  Widget _buildLegendForCategory() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor =
        isDark ? Colors.black.withOpacity(0.6) : Colors.white.withOpacity(0.8);
    final textColor = isDark ? Colors.white : Colors.black87;

    switch (_selectedCategory) {
      case DatasetCategory.parking:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.local_parking, color: Colors.green, size: 14),
              const SizedBox(width: 4),
              Text('frei', style: TextStyle(color: textColor, fontSize: 12)),
              const SizedBox(width: 8),
              const Icon(Icons.local_parking, color: Colors.red, size: 14),
              const SizedBox(width: 4),
              Text('belegt', style: TextStyle(color: textColor, fontSize: 12)),
              const SizedBox(width: 8),
              const Icon(Icons.local_parking, color: Colors.blue, size: 14),
              const SizedBox(width: 4),
              Text('Status unbekannt',
                  style: TextStyle(color: textColor, fontSize: 12)),
              const SizedBox(width: 8),
              const Icon(Icons.push_pin, color: Colors.teal, size: 14),
              const SizedBox(width: 4),
              Text('Einzelplatz',
                  style: TextStyle(color: textColor, fontSize: 12)),
            ],
          ),
        );

      case DatasetCategory.carsharing:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.directions_car, color: Colors.green, size: 14),
              const SizedBox(width: 4),
              Text('Fahrzeuge verfügbar',
                  style: TextStyle(color: textColor, fontSize: 12)),
              const SizedBox(width: 8),
              const Icon(Icons.directions_car, color: Colors.grey, size: 14),
              const SizedBox(width: 4),
              Text('nicht verfügbar',
                  style: TextStyle(color: textColor, fontSize: 12)),
            ],
          ),
        );
      case DatasetCategory.bikesharing:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.pedal_bike, color: Colors.green, size: 14),
              const SizedBox(width: 4),
              Text('verfügbar',
                  style: TextStyle(color: textColor, fontSize: 12)),
              const SizedBox(width: 8),
              const Icon(Icons.pedal_bike, color: Colors.red, size: 14),
              const SizedBox(width: 4),
              Text('leer', style: TextStyle(color: textColor, fontSize: 12)),
            ],
          ),
        );
      case DatasetCategory.scooters:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.electric_scooter,
                  color: Colors.lightGreen, size: 14),
              const SizedBox(width: 4),
              Text('fahrbereit',
                  style: TextStyle(color: textColor, fontSize: 12)),
              const SizedBox(width: 8),
              const Icon(Icons.electric_scooter,
                  color: Colors.orange, size: 14),
              const SizedBox(width: 4),
              Text('niedriger Akku',
                  style: TextStyle(color: textColor, fontSize: 12)),
            ],
          ),
        );

      default:
        return Container();
    }
  }

  ////////////////////////////////////////
  /// KATEGORIEN LISTE
  ////////////////////////////////////////

  Widget _buildCategoryTile(DatasetCategory cat, String label) {
    final isSelected = _selectedCategory == cat;
    final highlightColor =
        isSelected ? Theme.of(context).colorScheme.primary : null;

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
      leading: Icon(icon, color: highlightColor),
      title: Text(
        label,
        style: TextStyle(color: highlightColor),
      ),
      selected: isSelected,
      onTap: () => _onSelectCategory(cat),
    );
  }

  ////////////////////////////////////////
  /// DRAWER
  ////////////////////////////////////////
  void _onSelectCategory(DatasetCategory cat) {
    Navigator.of(context).pop();
    setState(() {
      _selectedCategory = cat;
    });
    _loadDataForCurrentCategory();
  }

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
