import 'dart:convert';

import 'package:dio/dio.dart';

import '../models/parking_site.dart';
import '../models/parking_spot.dart';
import '../services/cache_service.dart';

// TODO: Open status, realtime status
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

  // MobiData BW ParkAPI / DATEX-II-Light Endpoint
  static const String _parkingSitesEndpoint =
      'https://api.mobidata-bw.de/park-api/api/public/v3/parking-sites';
  static const String _parkingSpotsEndpoint =
      'https://api.mobidata-bw.de/park-api/api/public/v3/parking-spots';
  final CacheService _cache = CacheService();

  Future<List<ParkingSite>> fetchParkingSites({
    CancelToken? cancelToken,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cachedJson = _cache.loadParkingSites();
      if (cachedJson != null && cachedJson.isNotEmpty) {
        final cachedSites = <ParkingSite>[];
        for (final m in cachedJson) {
          final ps = ParkingSite.fromJson(m);
          if (ps != null) cachedSites.add(ps);
        }
        if (cachedSites.isNotEmpty) {
          return cachedSites;
        }
      }
    }

    final res = await _dio.get(
      _parkingSitesEndpoint,
      cancelToken: cancelToken,
    );

    dynamic data = res.data;
    if (data is String) {
      data = jsonDecode(data);
    }

    final List<ParkingSite> out = [];
    final List<Map<String, dynamic>> rawForCache = [];

    // fall: top-level List
    if (data is List) {
      for (final item in data) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item as Map);
        final ps = ParkingSite.fromJson(map);
        if (ps != null) {
          out.add(ps);
          rawForCache.add(map);
        }
      }
      if (out.isNotEmpty) {
        await _cache.saveParkingSites(rawForCache);
      }
      return out;
    }

    // fall: Map / Objekt
    if (data is Map<String, dynamic>) {
      // Wrapper "items" + "total_count"
      if (data['items'] is List) {
        final items = data['items'] as List;

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
                final siteMap = Map<String, dynamic>.from(s as Map);
                final ps = ParkingSite.fromJson(siteMap);
                if (ps != null) {
                  out.add(ps);
                  rawForCache.add(siteMap);
                }
              }
            }

            final spaces = ppl['parkingSpot'] ?? ppl['parkingSpace'];
            if (spaces is List) {
              for (final space in spaces) {
                if (space is! Map) continue;
                final spaceMap = Map<String, dynamic>.from(space as Map);
                final ps = ParkingSite.fromJson(spaceMap);
                if (ps != null) {
                  out.add(ps);
                  rawForCache.add(spaceMap);
                }
              }
            }
          }
        }

        if (out.isNotEmpty) {
          await _cache.saveParkingSites(rawForCache);
          return out;
        }
      }

      // GeoJSON
      if (data['features'] is List) {
        final features = data['features'] as List;
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
        if (out.isNotEmpty) {
          await _cache.saveParkingSites(rawForCache);
          return out;
        }
      }

      for (final entry in data.entries) {
        final v = entry.value;
        if (v is List && v.isNotEmpty && v.first is Map) {
          for (final item in v) {
            if (item is! Map) continue;
            final map = Map<String, dynamic>.from(item as Map);
            final ps = ParkingSite.fromJson(map);
            if (ps != null) {
              out.add(ps);
              rawForCache.add(map);
            }
          }

          if (out.isNotEmpty) {
            await _cache.saveParkingSites(rawForCache);
            return out;
          }
        }
      }
    }

    return out;
  }

  Future<List<ParkingSpot>> fetchParkingSpots({
    CancelToken? cancelToken,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cachedJson = _cache.loadParkingSpots();
      if (cachedJson != null && cachedJson.isNotEmpty) {
        final cachedSpots = <ParkingSpot>[];
        for (final m in cachedJson) {
          final spot = ParkingSpot.fromJson(m);
          if (spot != null) cachedSpots.add(spot);
        }
        if (cachedSpots.isNotEmpty) {
          return cachedSpots;
        }
      }
    }

    final res = await _dio.get(
      _parkingSpotsEndpoint,
      cancelToken: cancelToken,
    );

    dynamic data = res.data;
    if (data is String) {
      data = jsonDecode(data);
    }

    final List<ParkingSpot> out = [];
    final List<Map<String, dynamic>> rawForCache = [];

    void handleList(List list) {
      for (final item in list) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item as Map);
        final spot = ParkingSpot.fromJson(map);
        if (spot != null) {
          out.add(spot);
          rawForCache.add(map);
        }
      }
    }

    if (data is List) {
      handleList(data);
    } else if (data is Map<String, dynamic>) {
      if (data['items'] is List) {
        handleList(data['items'] as List);
      } else {
        for (final entry in data.entries) {
          final value = entry.value;
          if (value is List) {
            handleList(value);
          }
        }
      }
    }

    if (out.isNotEmpty) {
      await _cache.saveParkingSpots(rawForCache);
    }
    return out;
  }
}
