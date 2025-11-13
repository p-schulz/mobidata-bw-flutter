import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

class CacheService {
  static const _boxName = 'mobidata_cache';

  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;

    if (kIsWeb) {
      // fix for testing non-mobile
      await Hive.initFlutter();
    } else {
      // mobile/desktop
      final dir = await getApplicationDocumentsDirectory();
      Hive.init(dir.path);
    }

    await Hive.openBox(_boxName);
    _initialized = true;
  }

  static Box get _box => Hive.box(_boxName);

  CacheService._internal();
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;

  Future<void> saveJsonList(
    String key,
    List<Map<String, dynamic>> list,
  ) async {
    await _box.put(key, {
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'data': list,
    });
  }

  List<Map<String, dynamic>>? loadJsonList(
    String key, {
    Duration maxAge = const Duration(minutes: 3600),
  }) {
    final rec = _box.get(key);
    if (rec is! Map) return null;

    final ts = rec['timestamp'] as int?;
    if (ts == null) return null;

    final age = DateTime.now().millisecondsSinceEpoch - ts;
    if (age > maxAge.inMilliseconds) {
      return null;
    }

    final raw = rec['data'] as List<dynamic>?;
    if (raw == null) return null;

    return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  // keys
  static const String keyParkingSites = 'parking_sites_all';
  static const String keyParkingSpots = 'parking_spots_all';
  static const String keyTransitStationsOnly = 'transit_stations_only';
  static const String keyTransitStationsWithStops =
      'transit_stations_with_stops';
  static const String keyChargingStationsPrefix = 'charging_stations';
  static const String keyConstructionSites = 'construction_sites';

  Future<void> saveParkingSites(List<Map<String, dynamic>> list) =>
      saveJsonList(keyParkingSites, list);

  List<Map<String, dynamic>>? loadParkingSites({
    Duration maxAge = const Duration(minutes: 10),
  }) =>
      loadJsonList(keyParkingSites, maxAge: maxAge);

  Future<void> saveParkingSpots(List<Map<String, dynamic>> list) =>
      saveJsonList(keyParkingSpots, list);

  List<Map<String, dynamic>>? loadParkingSpots({
    Duration maxAge = const Duration(minutes: 5),
  }) =>
      loadJsonList(keyParkingSpots, maxAge: maxAge);

  Future<void> saveTransitStations(List<Map<String, dynamic>> list) =>
      saveJsonList(keyTransitStationsOnly, list);

  List<Map<String, dynamic>>? loadTransitStations({
    Duration maxAge = const Duration(hours: 1),
  }) =>
      loadJsonList(keyTransitStationsOnly, maxAge: maxAge);

  Future<void> saveTransitStationsWithStops(List<Map<String, dynamic>> list) =>
      saveJsonList(keyTransitStationsWithStops, list);

  List<Map<String, dynamic>>? loadTransitStationsWithStops({
    Duration maxAge = const Duration(hours: 1),
  }) =>
      loadJsonList(keyTransitStationsWithStops, maxAge: maxAge);

  Future<void> saveChargingStations(
    String cacheKey,
    List<Map<String, dynamic>> list,
  ) =>
      saveJsonList('$keyChargingStationsPrefix:$cacheKey', list);

  List<Map<String, dynamic>>? loadChargingStations(
    String cacheKey, {
    Duration maxAge = const Duration(minutes: 15),
  }) =>
      loadJsonList('$keyChargingStationsPrefix:$cacheKey', maxAge: maxAge);

  Future<void> saveConstructionSites(List<Map<String, dynamic>> list) =>
      saveJsonList(keyConstructionSites, list);

  List<Map<String, dynamic>>? loadConstructionSites({
    Duration maxAge = const Duration(hours: 6),
  }) =>
      loadJsonList(keyConstructionSites, maxAge: maxAge);
}
