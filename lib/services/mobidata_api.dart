import 'package:dio/dio.dart';

import 'dart:convert';

import '../models/parking_site.dart';

class MobiDataApi {
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: const {
        'Accept': 'application/json',
      },
    ),
  );

  Future<List<ParkingSite>> fetchParkingSites({CancelToken? cancelToken}) async {
    const url = 'https://api.mobidata-bw.de/park-api/api/public/v3/parking-sites';

    final res = await _dio.get(url, cancelToken: cancelToken);
    print('[MobiDataApi] status: ${res.statusCode}, type: ${res.data.runtimeType}');

    dynamic data = res.data;
    if (data is String) {
      data = jsonDecode(data);
    }

    final List<ParkingSite> out = [];

    // Fall: reine Liste
    if (data is List) {
      print('[MobiDataApi] top-level is List, length: ${data.length}');
      for (final item in data) {
        if (item is Map) {
          final ps = ParkingSite.fromJson(Map<String, dynamic>.from(item));
          if (ps != null) out.add(ps);
        }
      }
      print('[MobiDataApi] parsed sites from top-level List: ${out.length}');
      return out;
    }

    // Fall: Map / Objekt
    if (data is Map<String, dynamic>) {
      print('[MobiDataApi] map keys: ${data.keys.toList()}');

      // Fall: GeoJSON FeatureCollection?
      if (data['features'] is List) {
        final features = data['features'] as List;
        print('[MobiDataApi] features length: ${features.length}');
        for (final f in features) {
          if (f is! Map) continue;
          final m = Map<String, dynamic>.from(f);
          final props = m['properties'] is Map
              ? Map<String, dynamic>.from(m['properties'] as Map)
              : <String, dynamic>{};
          final geom = m['geometry'];
          final merged = <String, dynamic>{
            ...props,
            'geometry': geom,
          };
          final ps = ParkingSite.fromJson(merged);
          if (ps != null) out.add(ps);
        }
        print('[MobiDataApi] parsed sites from features: ${out.length}');
        if (out.isNotEmpty) return out;
      }

      // allgemeiner fallback:
      // suche nach irgendeinem feld, das eine liste von objekten enthält
      for (final entry in data.entries) {
        final v = entry.value;
        if (v is List && v.isNotEmpty && v.first is Map) {
          print('[MobiDataApi] trying list at key: ${entry.key}, length: ${v.length}');
          for (final item in v) {
            final ps = ParkingSite.fromJson(Map<String, dynamic>.from(item as Map));
            if (ps != null) out.add(ps);
          }
          print('[MobiDataApi] parsed sites from key ${entry.key}: ${out.length}');
          if (out.isNotEmpty) return out;
        }
      }

      print('[MobiDataApi] no suitable list found in map');
    }

    return out;
  }
}
*/