import 'dart:convert';

import 'package:dio/dio.dart';

import '../models/transit_departure.dart';
import '../models/transit_stop.dart';
import 'cache_service.dart';

class TransitApiService {
  TransitApiService()
      : _dio = Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 12),
            receiveTimeout: const Duration(seconds: 20),
            headers: const {
              'Accept': 'application/json',
              'Prefer': 'count=none',
            },
          ),
        );

  final Dio _dio;

  static const _stopsEndpoint = 'https://api.mobidata-bw.de/gtfs/stops';
  static const _arrivalsEndpoint =
      'https://api.mobidata-bw.de/gtfs/arrivals_departures';

  final CacheService _cache = CacheService();

  Future<List<TransitStop>> fetchStations({
    CancelToken? cancelToken,
    bool forceRefresh = false,
    int limit = 4000,
    bool includeStops = true,
  }) async {
    List<Map<String, dynamic>>? cached;
    if (!forceRefresh) {
      cached = includeStops
          ? _cache.loadTransitStationsWithStops()
          : _cache.loadTransitStations();
      if (cached != null && cached.isNotEmpty) {
        final fromCache =
            cached.map(TransitStop.fromJson).whereType<TransitStop>().toList();
        if (fromCache.isNotEmpty) return fromCache;
      }
    }

    final query = <String, dynamic>{
      'select': 'stop_id,stop_name,stop_desc,stop_loc,parent_station,location_type',
      'order': 'stop_name',
      'limit': limit,
    };
    if (!includeStops) {
      query['location_type'] = 'eq.station';
    }

    final res = await _dio.get(
      _stopsEndpoint,
      cancelToken: cancelToken,
      queryParameters: query,
    );

    dynamic data = res.data;
    if (data is String) {
      data = jsonDecode(data);
    }

    final stops = <TransitStop>[];
    final raw = <Map<String, dynamic>>[];

    if (data is List) {
      for (final item in data) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item as Map);
        final stop = TransitStop.fromJson(map);
        if (stop != null) {
          stops.add(stop);
          raw.add(map);
        }
      }
    }

    if (raw.isNotEmpty) {
      if (includeStops) {
        await _cache.saveTransitStationsWithStops(raw);
      } else {
        await _cache.saveTransitStations(raw);
      }
    }

    return stops;
  }

  Future<List<TransitDeparture>> fetchDeparturesForStation(
    String stationId, {
    CancelToken? cancelToken,
    int limit = 20,
  }) async {
    final query = {
      'or': '(station_id.eq.$stationId,stop_id.eq.$stationId)',
      'order': 't_departure.asc',
      'limit': limit,
    };

    Response res;
    try {
      res = await _dio.get(
        _arrivalsEndpoint,
        cancelToken: cancelToken,
        queryParameters: query,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 503) {
        throw Exception(
            'GTFS-Abfahrten aktuell nicht verfügbar (503 Service Unavailable)');
      }
      rethrow;
    }

    dynamic data = res.data;
    if (data is String) {
      data = jsonDecode(data);
    }

    final departures = <TransitDeparture>[];

    if (data is List) {
      for (final item in data) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item as Map);
        final dep = TransitDeparture.fromJson(map);
        if (dep != null) {
          departures.add(dep);
        }
      }
    }

    departures.sort((a, b) {
      final aTime = a.realtimeDeparture ?? a.scheduledDeparture;
      final bTime = b.realtimeDeparture ?? b.scheduledDeparture;
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return aTime.compareTo(bTime);
    });

    return departures;
  }
}
