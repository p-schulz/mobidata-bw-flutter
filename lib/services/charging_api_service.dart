import 'package:dio/dio.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlng;

import '../models/charging_station.dart';

class ChargingApiService {
  ChargingApiService()
      : _dio = Dio(
          BaseOptions(
            baseUrl: _baseUrl,
            connectTimeout: const Duration(seconds: 12),
            receiveTimeout: const Duration(seconds: 20),
            headers: const {'Accept': 'application/json'},
          ),
        );

  final Dio _dio;
  static const _baseUrl = 'https://api.mobidata-bw.de/ocpdb/api/public/v1';
  static const int _maxResults = 1000;

  Future<List<ChargingStation>> fetchStations({
    required LatLngBounds bounds,
    CancelToken? cancelToken,
  }) async {
    try {
      final centerLat = (bounds.north + bounds.south) / 2;
      final centerLon = (bounds.east + bounds.west) / 2;
      final radius = _radiusForBounds(bounds);

      final res = await _dio.get(
        '/locations',
        cancelToken: cancelToken,
        queryParameters: {
          'lat': centerLat,
          'lon': centerLon,
          'radius': radius,
          'limit': _maxResults,
        },
      );

      if (res.data is! Map || res.data['items'] is! List) {
        throw Exception('Unexpected charging response format');
      }

      final items = (res.data['items'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      return _mapStations(items);
    } catch (e) {
      rethrow;
    }
  }

  int _radiusForBounds(LatLngBounds bounds) {
    final latLngCenter = latlng.LatLng(
      (bounds.north + bounds.south) / 2,
      (bounds.east + bounds.west) / 2,
    );
    final corner = latlng.LatLng(bounds.north, bounds.east);
    final distance = latlng.Distance();
    final meters =
        distance.as(latlng.LengthUnit.Meter, latLngCenter, corner).clamp(500, 20000);
    return meters.round();
  }

  List<ChargingStation> _mapStations(List<Map<String, dynamic>> data) =>
      data.map(ChargingStation.fromJson).whereType<ChargingStation>().toList();
}
