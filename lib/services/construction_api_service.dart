import 'package:dio/dio.dart';

import '../models/construction_site.dart';
import 'cache_service.dart';

class ConstructionApiService {
  ConstructionApiService()
      : _dio = Dio(
          BaseOptions(
            baseUrl:
                'https://api.mobidata-bw.de/datasets/traffic/roadworks',
            connectTimeout: const Duration(seconds: 12),
            receiveTimeout: const Duration(seconds: 20),
            headers: const {'Accept': 'application/json'},
          ),
        ),
        _cache = CacheService();

  final Dio _dio;
  final CacheService _cache;

  Future<List<ConstructionSite>> fetchSites({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = _cache.loadConstructionSites();
      if (cached != null && cached.isNotEmpty) {
        return cached
            .map(ConstructionSite.fromFeature)
            .whereType<ConstructionSite>()
            .toList();
      }
    }

    try {
      final res = await _dio.get('/roadworks_geojson.json');
      if (res.data is! Map || res.data['features'] is! List) {
        return const [];
      }

      final features = (res.data['features'] as List)
          .map((f) => Map<String, dynamic>.from(f as Map))
          .toList();

      final sites = features
          .map(ConstructionSite.fromFeature)
          .whereType<ConstructionSite>()
          .toList();

      if (features.isNotEmpty) {
        await _cache.saveConstructionSites(features);
      }

      return sites;
    } catch (e) {
      final fallback =
          _cache.loadConstructionSites(maxAge: const Duration(days: 1));
      if (fallback != null && fallback.isNotEmpty) {
        return fallback
            .map(ConstructionSite.fromFeature)
            .whereType<ConstructionSite>()
            .toList();
      }
      rethrow;
    }
  }
}
