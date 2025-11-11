import 'dart:convert';

import 'package:dio/dio.dart';

import '../models/carsharing_offer.dart';
import '../services/cache_service.dart';

class CarsharingApiService {
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: const {
        'Accept': 'application/json',
      },
    ),
  );

  // TODO: an tatsächlichen MobiData-Carsharing-Endpunkt anpassen
  static const String _carsharingEndpoint =
      'https://api.mobidata-bw.de/.../carsharing/...';

  final CacheService _cache = CacheService();

  Future<List<CarsharingOffer>> fetchCarsharingOffers({
    CancelToken? cancelToken,
    bool forceRefresh = false,
  }) async {
    // 1) Cache versuchen
    if (!forceRefresh) {
      final cachedJson = _cache.loadCarsharingOffers();
      if (cachedJson != null && cachedJson.isNotEmpty) {
        final out = <CarsharingOffer>[];
        for (final m in cachedJson) {
          final offer = CarsharingOffer.fromJson(m);
          if (offer != null) out.add(offer);
        }
        if (out.isNotEmpty) {
          print(
              '[CarsharingApiService] using cached carsharing offers: ${out.length}');
          return out;
        }
      }
    }

    // 2) HTTP-Request
    final res = await _dio.get(
      _carsharingEndpoint,
      cancelToken: cancelToken,
    );

    print(
        '[CarsharingApiService] status: ${res.statusCode}, type: ${res.data.runtimeType}');

    dynamic data = res.data;
    if (data is String) {
      data = jsonDecode(data);
    }

    final List<CarsharingOffer> out = [];
    final List<Map<String, dynamic>> rawForCache = [];

    // Beispiel: GBFS-ähnlich: { "data": { "stations": [ ... ] } }
    if (data is Map<String, dynamic>) {
      final stations = data['data']?['stations'];
      if (stations is List) {
        for (final s in stations) {
          if (s is! Map) continue;
          final map = Map<String, dynamic>.from(s as Map);
          final offer = CarsharingOffer.fromJson(map);
          if (offer != null) {
            out.add(offer);
            rawForCache.add(map);
          }
        }
      }
    } else if (data is List) {
      // Fallback: reine Liste
      for (final s in data) {
        if (s is! Map) continue;
        final map = Map<String, dynamic>.from(s as Map);
        final offer = CarsharingOffer.fromJson(map);
        if (offer != null) {
          out.add(offer);
          rawForCache.add(map);
        }
      }
    }

    print('[CarsharingApiService] parsed carsharing offers: ${out.length}');

    if (out.isNotEmpty) {
      await _cache.saveCarsharingOffers(rawForCache);
    }

    return out;
  }
}
