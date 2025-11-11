import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

class CacheService {
  static const _boxName = 'parking_cache';

  static Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    Hive.init(dir.path);
    await Hive.openBox(_boxName);
  }

  Future<void> saveParkingSites(
      String key, List<Map<String, dynamic>> list) async {
    final box = Hive.box(_boxName);
    await box.put(key, {
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'data': list,
    });
  }

  List<Map<String, dynamic>>? loadParkingSites(String key,
      {Duration maxAge = const Duration(minutes: 10)}) {
    final box = Hive.box(_boxName);
    final rec = box.get(key) as Map?;
    if (rec == null) return null;
    final ts = rec['timestamp'] as int;
    final age = DateTime.now().millisecondsSinceEpoch - ts;
    if (age > maxAge.inMilliseconds) {
      return null;
    }
    final raw = rec['data'] as List<dynamic>;
    return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
}
