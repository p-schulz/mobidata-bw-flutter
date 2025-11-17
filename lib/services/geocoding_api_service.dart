import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

class GeocodingApiService {
  GeocodingApiService()
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

  Future<LatLng?> geocode(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return null;

    print('[Geocoder] Requesting "$trimmed"...');
    final res = await _dio.get(
      '/locations/search', //'/geocode',
      queryParameters: {'q': trimmed},
    );
    print(
        '[Geocoder] Status: ${res.statusCode}, type: ${res.data.runtimeType}');

    Map<String, dynamic>? record;
    final data = res.data;

    if (data is Map<String, dynamic>) {
      record = _extractEntry(data);
    } else if (data is List && data.isNotEmpty) {
      final first = data.first;
      if (first is Map) {
        record = Map<String, dynamic>.from(first as Map);
      }
    }

    if (record == null) {
      print('[Geocoder] No usable record for "$trimmed"');
      return null;
    }

    final lat = _toDouble(
      record['lat'] ??
          record['latitude'] ??
          record['y'] ??
          record['latDeg'] ??
          record['lat_deg'],
    );
    final lon = _toDouble(
      record['lon'] ??
          record['longitude'] ??
          record['x'] ??
          record['lonDeg'] ??
          record['lon_deg'],
    );

    if (lat == null || lon == null) {
      print('[Geocoder] Missing coordinates for "$trimmed" -> $record');
      return null;
    }
    print('[Geocoder] Resolved "$trimmed" to $lat,$lon');
    return LatLng(lat, lon);
  }

  Map<String, dynamic>? _extractEntry(Map<String, dynamic> data) {
    dynamic first;
    if (data['results'] is List && (data['results'] as List).isNotEmpty) {
      first = (data['results'] as List).first;
    } else if (data['items'] is List && (data['items'] as List).isNotEmpty) {
      first = (data['items'] as List).first;
    } else if (data['locations'] is List &&
        (data['locations'] as List).isNotEmpty) {
      first = (data['locations'] as List).first;
    } else if (data['features'] is List &&
        (data['features'] as List).isNotEmpty) {
      final f = (data['features'] as List).first;
      if (f is Map && f['geometry'] is Map) {
        final geom = f['geometry'] as Map;
        final coords = geom['coordinates'];
        if (coords is List && coords.length >= 2) {
          return {
            'lon': coords[0],
            'lat': coords[1],
          };
        }
      }
      first = f;
    } else if (data.containsKey('lat') && data.containsKey('lon')) {
      return data;
    }

    if (first is Map) {
      return Map<String, dynamic>.from(first as Map);
    }
    return null;
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}
