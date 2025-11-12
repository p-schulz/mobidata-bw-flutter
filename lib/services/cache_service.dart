import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

class CacheService {
  static const _boxName = 'mobidata_cache';

  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;

    if (kIsWeb) {
      // fix um web-variante testen zu können
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
    Duration maxAge = const Duration(minutes: 10),
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

  // parkplätze
  Future<void> saveParkingSites(List<Map<String, dynamic>> list) =>
      saveJsonList(keyParkingSites, list);

  List<Map<String, dynamic>>? loadParkingSites({
    Duration maxAge = const Duration(minutes: 10),
  }) =>
      loadJsonList(keyParkingSites, maxAge: maxAge);

  // weitere caches bei Bedarf ergänzen
}
