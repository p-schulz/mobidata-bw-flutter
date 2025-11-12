import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/bikesharing_station.dart';
import '../models/carsharing_offer.dart';
import '../models/scooter_vehicle.dart';
import 'cache_service.dart';

class SharingApiService {
  SharingApiService()
      : _dio = Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 12),
            receiveTimeout: const Duration(seconds: 20),
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
          ),
        );

  final Dio _dio;
  final CacheService _cache = CacheService();

  static const _graphqlEndpoint = 'https://api.mobidata-bw.de/sharing/graphql';
  static const _defaultMinLat = 47.0;
  static const _defaultMaxLat = 50.0;
  static const _defaultMinLon = 5.0;
  static const _defaultMaxLon = 11.5;
  static const _stationCountLimit = 5000;
  static const _vehicleCountLimit = 8000;

  /// Fetches all car sharing stations within the default BW bounding box.
  Future<List<CarsharingOffer>> fetchCarsharingOffers({
    LatLngBounds? bounds,
    bool forceRefresh = false,
    Set<String>? allowedSystemIds,
  }) async {
    final cached = !forceRefresh ? _cache.loadCarsharingOffers() : null;
    if (cached != null && cached.isNotEmpty) {
      return _mapList(cached, CarsharingOffer.fromJson);
    }

    final stations = await _fetchStations(
      bounds: bounds,
      formFactors: const ['CAR'],
    );

    final normalized = stations
        .where((s) => _isSystemAllowed(s, allowedSystemIds))
        .map(_normalizeStationForCache)
        .whereType<Map<String, dynamic>>()
        .toList();

    if (normalized.isNotEmpty) {
      await _cache.saveCarsharingOffers(normalized);
    }

    return _mapList(normalized, CarsharingOffer.fromJson);
  }

  /// Fetches all bike sharing stations (includes cargo bikes).
  Future<List<BikesharingStation>> fetchBikesharingStations({
    LatLngBounds? bounds,
    bool forceRefresh = false,
    Set<String>? allowedSystemIds,
  }) async {
    final cached = !forceRefresh ? _cache.loadBikesharingStations() : null;
    if (cached != null && cached.isNotEmpty) {
      return _mapList(cached, BikesharingStation.fromJson);
    }

    final stations = await _fetchStations(
      bounds: bounds,
      formFactors: const ['BICYCLE', 'CARGO_BICYCLE'],
    );

    final normalized = stations
        .where((s) => _isSystemAllowed(s, allowedSystemIds))
        .map(_normalizeStationForCache)
        .whereType<Map<String, dynamic>>()
        .toList();

    if (normalized.isNotEmpty) {
      await _cache.saveBikesharingStations(normalized);
    }

    return _mapList(normalized, BikesharingStation.fromJson);
  }

  /// Fetches all scooters / mopeds as free-floating vehicles.
  Future<List<ScooterVehicle>> fetchScooterVehicles({
    LatLngBounds? bounds,
    bool forceRefresh = false,
    Set<String>? allowedSystemIds,
  }) async {
    final cached = !forceRefresh ? _cache.loadScooterVehicles() : null;
    if (cached != null && cached.isNotEmpty) {
      return _mapList(cached, ScooterVehicle.fromJson);
    }

    final vehicles = await _fetchVehicles(
      bounds: bounds,
      formFactors: const ['SCOOTER_STANDING', 'SCOOTER_SEATED', 'MOPED'],
    );

    final normalized = vehicles
        .where((v) => _isSystemAllowed(v, allowedSystemIds))
        .map(_normalizeVehicleForCache)
        .whereType<Map<String, dynamic>>()
        .toList();

    if (normalized.isNotEmpty) {
      await _cache.saveScooterVehicles(normalized);
    }

    return _mapList(normalized, ScooterVehicle.fromJson);
  }

  Future<List<Map<String, dynamic>>> _fetchStations({
    LatLngBounds? bounds,
    required List<String> formFactors,
  }) async {
    final b = bounds ?? _defaultBounds;
    final variables = {
      'minLat': b.south,
      'maxLat': b.north,
      'minLon': b.west,
      'maxLon': b.east,
      'formFactors': formFactors,
      'count': _stationCountLimit,
    };

    const query = r'''
      query Stations($minLat: Float!, $maxLat: Float!, $minLon: Float!, $maxLon: Float!, $formFactors: [FormFactor!], $count: Int!) {
        stations(
          minimumLatitude: $minLat,
          maximumLatitude: $maxLat,
          minimumLongitude: $minLon,
          maximumLongitude: $maxLon,
          availableFormFactors: $formFactors,
          count: $count
        ) {
          id
          name { translation { language value } }
          lat
          lon
          numVehiclesAvailable
          isRenting
          system {
            id
            name { translation { language value } }
          }
          vehicleTypesAvailable {
            vehicleType {
              id
              formFactor
              name { translation { language value } }
            }
            count
          }
        }
      }
    ''';

    final data = await _postGraphQL(query, variables);
    final stations = data?['stations'];
    if (stations is List) {
      return stations
          .whereType<Map<String, dynamic>>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return const [];
  }

  Future<List<Map<String, dynamic>>> _fetchVehicles({
    LatLngBounds? bounds,
    required List<String> formFactors,
  }) async {
    final b = bounds ?? _defaultBounds;
    final variables = {
      'minLat': b.south,
      'maxLat': b.north,
      'minLon': b.west,
      'maxLon': b.east,
      'formFactors': formFactors,
      'count': _vehicleCountLimit,
    };

    const query = r'''
      query Vehicles($minLat: Float!, $maxLat: Float!, $minLon: Float!, $maxLon: Float!, $formFactors: [FormFactor!], $count: Int!) {
        vehicles(
          minimumLatitude: $minLat,
          maximumLatitude: $maxLat,
          minimumLongitude: $minLon,
          maximumLongitude: $maxLon,
          formFactors: $formFactors,
          includeReserved: false,
          includeDisabled: false,
          count: $count
        ) {
          id
          lat
          lon
          isReserved
          isDisabled
          currentRangeMeters
          currentFuelPercent
          system {
            id
            name { translation { language value } }
          }
          vehicleType {
            id
            formFactor
            name { translation { language value } }
          }
        }
      }
    ''';

    final data = await _postGraphQL(query, variables);
    final vehicles = data?['vehicles'];
    if (vehicles is List) {
      return vehicles
          .whereType<Map<String, dynamic>>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return const [];
  }

  Future<Map<String, dynamic>?> _postGraphQL(
    String query,
    Map<String, dynamic> variables,
  ) async {
    final response = await _dio.post(
      _graphqlEndpoint,
      data: jsonEncode({'query': query, 'variables': variables}),
    );

    dynamic data = response.data;
    if (data is String) {
      data = jsonDecode(data);
    }

    if (data is! Map) {
      throw Exception('Ungültige Antwort vom Sharing-API');
    }

    final errors = data['errors'];
    if (errors is List && errors.isNotEmpty) {
      throw Exception(errors.first['message'] ?? 'Sharing-API Fehler');
    }

    return data['data'] as Map<String, dynamic>?;
  }

  Map<String, dynamic>? _normalizeStationForCache(
      Map<String, dynamic> rawStation) {
    try {
      final system = rawStation['system'] as Map<String, dynamic>?;
      final providerName = _translated(system?['name']) ?? system?['id'];
      final stationName = _translated(rawStation['name']);
      final vehicles = rawStation['vehicleTypesAvailable'] as List<dynamic>?;
      final firstVehicle = vehicles?.firstWhere(
        (element) =>
            element is Map<String, dynamic> &&
            element['vehicleType'] != null,
        orElse: () => null,
      );

      String vehicleType = 'Fahrzeug';
      if (firstVehicle is Map<String, dynamic>) {
        final vt = firstVehicle['vehicleType'];
        vehicleType = _translated(vt?['name']) ?? vehicleType;
      }

      return {
        'station_id': rawStation['id'],
        'name': stationName ?? 'Station',
        'lat': rawStation['lat'],
        'lon': rawStation['lon'],
        'available_vehicles': rawStation['numVehiclesAvailable'] ?? 0,
        'is_renting_allowed': rawStation['isRenting'] ?? true,
        'provider': providerName ?? 'unbekannt',
        'vehicle_type': vehicleType,
      };
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic>? _normalizeVehicleForCache(
      Map<String, dynamic> rawVehicle) {
    try {
      final system = rawVehicle['system'] as Map<String, dynamic>?;
      final providerName = _translated(system?['name']) ?? system?['id'];
      final vehicleType = _translated(
            (rawVehicle['vehicleType'] as Map<String, dynamic>?)?['name'],
          ) ??
          'Scooter';

      return {
        'bike_id': rawVehicle['id'],
        'lat': rawVehicle['lat'],
        'lon': rawVehicle['lon'],
        'is_reserved': rawVehicle['isReserved'],
        'is_disabled': rawVehicle['isDisabled'],
        'current_range_meters': rawVehicle['currentRangeMeters'],
        'current_fuel_percent': rawVehicle['currentFuelPercent'],
        'provider': providerName ?? 'unbekannt',
        'vehicle_type': vehicleType,
      };
    } catch (_) {
      return null;
    }
  }

  bool _isSystemAllowed(
    Map<String, dynamic> node,
    Set<String>? allowedSystems,
  ) {
    if (allowedSystems == null || allowedSystems.isEmpty) return true;
    final system = node['system'] as Map<String, dynamic>?;
    final id = system?['id'] ?? node['system_id'];
    if (id is String) {
      return allowedSystems.contains(id);
    }
    return true;
  }

  List<T> _mapList<T>(
    List<Map<String, dynamic>> input,
    T? Function(Map<String, dynamic>) mapper,
  ) {
    final result = <T>[];
    for (final item in input) {
      final obj = mapper(item);
      if (obj != null) result.add(obj);
    }
    return result;
  }

  static String? _translated(dynamic translated) {
    if (translated is Map) {
      final translations = translated['translation'];
      if (translations is List && translations.isNotEmpty) {
        Map<String, dynamic>? de;
        for (final entry in translations) {
          if (entry is Map<String, dynamic>) {
            if ((entry['language'] as String?)?.toLowerCase() == 'de') {
              de = entry;
              break;
            }
          }
        }
        final target = de ?? translations.first as Map<String, dynamic>?;
        return target?['value']?.toString();
      }
    }
    if (translated is String) return translated;
    return null;
  }

  static LatLngBounds get _defaultBounds {
    return LatLngBounds(
      const LatLng(_defaultMinLat, _defaultMinLon),
      const LatLng(_defaultMaxLat, _defaultMaxLon),
    );
  }
}

typedef CarsharingApiService = SharingApiService;
