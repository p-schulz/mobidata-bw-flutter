import 'dart:convert';

import 'package:dio/dio.dart';

import '../models/parking_site.dart';
import '../services/cache_service.dart';

class ParkApiService {
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: const {
        'Accept': 'application/json',
      },
    ),
  );

  static const String _parkEndpoint =
      'https://api.mobidata-bw.de/park-api/api/public/v3/parking-sites';

  static const String _cacheKeyParkingSites = 'parking_sites_all';

  final CacheService _cache = CacheService();

  Future<List<ParkingSite>> fetchParkingSites({
    CancelToken? cancelToken,
    bool forceRefresh = false,
  }) async {
    print('[ParkApiService] checking cache for parking sites…');
    if (!forceRefresh) {
      // fixed: key übergeben
      print('[ParkApiService] looking for cached parking sites with key');
      final cached = _cache.loadParkingSites(_cacheKeyParkingSites);
      if (cached != null && cached.isNotEmpty) {
        final cachedSites = <ParkingSite>[];
        for (final m in cached) {
          final ps = ParkingSite.fromJson(m);
          if (ps != null) cachedSites.add(ps);
        }
        if (cachedSites.isNotEmpty) {
          print(
              '[ParkApiService] using cached parking sites: ${cachedSites.length}');
          return cachedSites;
        }
      }
    }

    print(
        '[ParkApiService] no cached parking sites found or force refresh requested, fetching from API…');

    // kein (brauchbarer) cache: HTTP-Request
    final res = await _dio.get(
      _parkEndpoint,
      cancelToken: cancelToken,
    );

    print(
        '[ParkApiService] status: ${res.statusCode}, type: ${res.data.runtimeType}');

    dynamic data = res.data;
    if (data is String) {
      data = jsonDecode(data);
    }

    final List<ParkingSite> out = [];
    final List<Map<String, dynamic>> rawForCache = [];

    // Fall: top-level Liste
    if (data is List) {
      print('[ParkApiService] top-level List length: ${data.length}');
      for (final item in data) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item as Map);
        final ps = ParkingSite.fromJson(map);
        if (ps != null) {
          out.add(ps);
          rawForCache.add(map);
        }
      }
      print('[ParkApiService] parsed sites from top-level list: ${out.length}');
      if (out.isNotEmpty) {
        await _cache.saveParkingSites(_cacheKeyParkingSites, rawForCache);
      }
      return out;
    }

    // Fall: Map / Objekt
    if (data is Map<String, dynamic>) {
      print('[ParkApiService] map keys: ${data.keys.toList()}');

      // wrapper "items" + "total_count"
      if (data['items'] is List) {
        final items = data['items'] as List;
        print('[ParkApiService] items length: ${items.length}');

        for (final item in items) {
          if (item is! Map) continue;
          final m = Map<String, dynamic>.from(item as Map);

          final ppl = m['parkingPublicationLight'];
          if (ppl is Map<String, dynamic>) {
            final sites = ppl['parkingSite'];
            if (sites is List) {
              for (final s in sites) {
                if (s is! Map) continue;
                final siteMap = Map<String, dynamic>.from(s as Map);
                final ps = ParkingSite.fromJson(siteMap);
                if (ps != null) {
                  out.add(ps);
                  rawForCache.add(siteMap);
                }
              }
            }
          }
        }

        print('[ParkApiService] parsed sites from items: ${out.length}');
        if (out.isNotEmpty) {
          await _cache.saveParkingSites(_cacheKeyParkingSites, rawForCache);
          return out;
        }
      }

      // GeoJSON
      if (data['features'] is List) {
        final features = data['features'] as List;
        print('[ParkApiService] features length: ${features.length}');
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
          if (ps != null) {
            out.add(ps);
            rawForCache.add(merged);
          }
        }
        print('[ParkApiService] parsed sites from features: ${out.length}');
        if (out.isNotEmpty) {
          await _cache.saveParkingSites(_cacheKeyParkingSites, rawForCache);
          return out;
        }
      }

      // fallback
      for (final entry in data.entries) {
        final v = entry.value;
        if (v is List && v.isNotEmpty && v.first is Map) {
          print(
              '[ParkApiService] trying list at key: ${entry.key}, length: ${v.length}');
          for (final item in v) {
            if (item is! Map) continue;
            final map = Map<String, dynamic>.from(item as Map);
            final ps = ParkingSite.fromJson(map);
            if (ps != null) {
              out.add(ps);
              rawForCache.add(map);
            }
          }
          print(
              '[ParkApiService] parsed sites from key ${entry.key}: ${out.length}');
          if (out.isNotEmpty) {
            await _cache.saveParkingSites(_cacheKeyParkingSites, rawForCache);
            return out;
          }
        }
      }

      print('[ParkApiService] no suitable list found in map');
    }

    return out;
  }
}
