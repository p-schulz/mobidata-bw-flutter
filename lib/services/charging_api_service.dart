import 'package:dio/dio.dart';
import 'package:flutter_map/flutter_map.dart';

import '../models/charging_station.dart';
import 'cache_service.dart';

class ChargingApiService {
  ChargingApiService()
      : _dio = Dio(
          BaseOptions(
            baseUrl: _baseUrl,
            connectTimeout: const Duration(seconds: 12),
            receiveTimeout: const Duration(seconds: 20),
            headers: const {'Accept': 'application/json'},
          ),
        ),
        _cache = CacheService();

  final Dio _dio;
  final CacheService _cache;
  static const _baseUrl =
      'https://api.mobidata-bw.de/ocpdb/api/public/v1';
  static const int _pageSize = 500;
  static const int _maxPages = 10;

  Future<List<ChargingStation>> fetchStations({
    required LatLngBounds bounds,
    CancelToken? cancelToken,
    bool forceRefresh = false,
  }) async {
    final cacheKey = _boundsCacheKey(bounds);
    if (!forceRefresh) {
      final cached =
          _cache.loadChargingStations(cacheKey, maxAge: const Duration(minutes: 20));
      if (cached != null && cached.isNotEmpty) {
        return _mapStations(cached);
      }
    }

    try {
      final allItems = <Map<String, dynamic>>[];
      final bbox =
          '${bounds.west},${bounds.south},${bounds.east},${bounds.north}';

      for (int page = 0; page < _maxPages; page++) {
        final offset = page * _pageSize;
        final res = await _dio.get(
          '/locations',
          cancelToken: cancelToken,
          queryParameters: {
            'bbox': bbox,
            'limit': _pageSize,
            'offset': offset,
          },
        );
        if (res.data is! Map || res.data['items'] is! List) {
          throw Exception('Unexpected charging response format');
        }

        final items = (res.data['items'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        allItems.addAll(items);

        if (items.length < _pageSize) {
          break;
        }
      }

      if (allItems.isEmpty) {
        return const [];
      }

      final stations = _mapStations(allItems);

      if (stations.isNotEmpty) {
        await _cache.saveChargingStations(cacheKey, allItems);
      }

      return stations;
    } catch (e) {
      final fallback =
          _cache.loadChargingStations(cacheKey, maxAge: const Duration(hours: 1));
      if (fallback != null && fallback.isNotEmpty) {
        return _mapStations(fallback);
      }
      rethrow;
    }
  }

  String _boundsCacheKey(LatLngBounds bounds) {
    String fmt(double v) => v.toStringAsFixed(3);
    return '${fmt(bounds.west)}_${fmt(bounds.south)}_${fmt(bounds.east)}_${fmt(bounds.north)}';
  }

  List<ChargingStation> _mapStations(List<Map<String, dynamic>> data) =>
      data.map(ChargingStation.fromJson).whereType<ChargingStation>().toList();
}
