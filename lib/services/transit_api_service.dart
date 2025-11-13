import 'package:dio/dio.dart';
import 'package:flutter_map/flutter_map.dart';

import '../models/transit_departure.dart';
import '../models/transit_stop.dart';

class TransitApiService {
  TransitApiService()
      : _dio = Dio(
          BaseOptions(
            baseUrl: _baseUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 20),
            headers: const {
              'Accept': 'application/json',
              'x-api-key': _apiKey,
            },
          ),
        );

  final Dio _dio;

  static const _baseUrl = 'http://85.215.128.121:8080';
  static const _apiKey =
      'a9f88d7fe78f3e1dcdecc6e22c818c43f4d71fe549d4a28aac2d7892c8be6a2e';

  Future<List<TransitStop>> fetchStops({
    required LatLngBounds bounds,
    CancelToken? cancelToken,
  }) async {
    final res = await _dio.get(
      '/stops/bbox',
      cancelToken: cancelToken,
      queryParameters: {
        'south': bounds.south,
        'west': bounds.west,
        'north': bounds.north,
        'east': bounds.east,
      },
    );
    if (res.data is Map && res.data['stops'] is List) {
      final stops = res.data['stops'] as List;
      return stops
          .map((e) => TransitStop.fromJson(Map<String, dynamic>.from(e)))
          .whereType<TransitStop>()
          .toList();
    }
    return const [];
  }

  Future<List<TransitDeparture>> fetchDepartures({
    required String stopId,
    String? stopName,
    int maxResults = 20,
    int horizonMinutes = 60,
    CancelToken? cancelToken,
  }) async {
    try {
      final res = await _dio.get(
        '/departures',
        cancelToken: cancelToken,
        queryParameters: {
          'stop_id': stopId,
          'max_results': maxResults,
          'horizon_min': horizonMinutes,
        },
      );
      if (res.statusCode == 404) {
        return const [];
      }
      if (res.data is! Map || res.data['departures'] is! List) {
        return const [];
      }
      final departures = res.data['departures'] as List;
      final now = DateTime.now();

      return departures
          .map((item) => _mapDeparture(
                Map<String, dynamic>.from(item),
                stopId: stopId,
                stopName: stopName,
                reference: now,
              ))
          .whereType<TransitDeparture>()
          .toList();
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return const [];
      }
      rethrow;
    }
  }

  TransitDeparture? _mapDeparture(
    Map<String, dynamic> json, {
    required String stopId,
    String? stopName,
    required DateTime reference,
  }) {
    final tripId = json['trip_id']?.toString();
    final line = json['line']?.toString();
    final departureTime = json['departure_time']?.toString();
    if (tripId == null || tripId.isEmpty || departureTime == null) {
      return null;
    }

    final scheduled = _combineDateAndTime(reference, departureTime);

    return TransitDeparture(
      id: tripId,
      routeShortName: line ?? json['route_id']?.toString() ?? 'Linie',
      routeLongName: json['route_id']?.toString(),
      routeType: json['route_type']?.toString(),
      headsign: json['headsign']?.toString(),
      stopName: stopName,
      stationName: stopName,
      stopId: stopId,
      stopSequence: _toInt(json['stop_sequence']),
      scheduledDeparture: scheduled,
      realtimeDeparture: scheduled,
      delayMinutes: 0,
    );
  }

  DateTime _combineDateAndTime(DateTime reference, String time) {
    final parts = time.split(':');
    final h = parts.length > 0 ? int.tryParse(parts[0]) ?? 0 : 0;
    final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    final s = parts.length > 2 ? int.tryParse(parts[2]) ?? 0 : 0;
    var result = DateTime(
      reference.year,
      reference.month,
      reference.day,
      h,
      m,
      s,
    );
    if (result.isBefore(reference.subtract(const Duration(minutes: 5)))) {
      result = result.add(const Duration(days: 1));
    }
    return result;
  }

  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}
