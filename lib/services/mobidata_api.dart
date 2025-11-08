import 'dart:convert';

import 'package:dio/dio.dart';

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

  // MobiData BW ParkAPI / DATEX-II-Light Endpoint
  static const String _parkEndpoint =
      'https://api.mobidata-bw.de/park-api/api/public/v3/parking-sites';

  Future<List<ParkingSite>> fetchParkingSites({CancelToken? cancelToken}) async {
    final res = await _dio.get(
      _parkEndpoint,
      cancelToken: cancelToken,
    );

    print(
        '[MobiDataApi] status: ${res.statusCode}, type: ${res.data.runtimeType}');

    dynamic data = res.data;
    if (data is String) {
      data = jsonDecode(data);
    }

    final List<ParkingSite> out = [];

    if (data is List) {
      print('[MobiDataApi] top-level List length: ${data.length}');
      for (final item in data) {
        if (item is! Map) continue;
        final ps =
        ParkingSite.fromJson(Map<String, dynamic>.from(item as Map));
        if (ps != null) out.add(ps);
      }
      print('[MobiDataApi] parsed sites from top-level list: ${out.length}');
      return out;
    }

    if (data is Map<String, dynamic>) {
      print('[MobiDataApi] map keys: ${data.keys.toList()}');

      // Wrapper "items" + "total_count"
      if (data['items'] is List) {
        final items = data['items'] as List;
        print('[MobiDataApi] items length: ${items.length}');

        for (final item in items) {
          if (item is! Map) continue;
          final m = Map<String, dynamic>.from(item as Map);

          final ppl = m['parkingPublicationLight'];
          if (ppl is Map<String, dynamic>) {
            // DATEX-II: parkingPublicationLight.parkingSite[]
            final sites = ppl['parkingSite'];
            if (sites is List) {
              for (final s in sites) {
                if (s is! Map) continue;
                final ps = ParkingSite.fromJson(
                  Map<String, dynamic>.from(s as Map),
                );
                if (ps != null) out.add(ps);
              }
            }

            // final spaces = ppl['parkingSpace'];
            // ...
          }
        }

        print('[MobiDataApi] parsed sites from items: ${out.length}');
        if (out.isNotEmpty) return out;
      }

      if (data['features'] is List) {
        final features = data['features'] as List;
        print('[MobiDataApi] features length: ${features.length}');
        for (final f in features) {
          if (f is! Map) continue;
          final m = Map<String, dynamic>.from(f as Map);
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

      for (final entry in data.entries) {
        final v = entry.value;
        if (v is List && v.isNotEmpty && v.first is Map) {
          print(
              '[MobiDataApi] trying list at key: ${entry.key}, length: ${v.length}');
          for (final item in v) {
            if (item is! Map) continue;
            final ps = ParkingSite.fromJson(
              Map<String, dynamic>.from(item as Map),
            );
            if (ps != null) out.add(ps);
          }
          print(
              '[MobiDataApi] parsed sites from key ${entry.key}: ${out.length}');
          if (out.isNotEmpty) return out;
        }
      }

      print('[MobiDataApi] no suitable list found in map');
    }

    return out;
  }
}
