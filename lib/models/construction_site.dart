class ConstructionSite {
  final String id;
  final String? type;
  final String? subtype;
  final String? description;
  final String? street;
  final String? direction;
  final String? reference;
  final DateTime? startTime;
  final DateTime? endTime;
  final double lat;
  final double lon;
  final List<List<double>> coordinates;

  ConstructionSite({
    required this.id,
    required this.lat,
    required this.lon,
    required this.coordinates,
    this.type,
    this.subtype,
    this.description,
    this.street,
    this.direction,
    this.reference,
    this.startTime,
    this.endTime,
  });

  static ConstructionSite? fromFeature(Map<String, dynamic> feature) {
    if (feature['geometry'] is! Map) return null;
    final geometry = feature['geometry'] as Map;
    if (geometry['type'] != 'LineString') return null;
    final coords = geometry['coordinates'];
    if (coords is! List || coords.isEmpty) return null;
    final parsed = <List<double>>[];
    for (final item in coords) {
      if (item is List && item.length >= 2) {
        final lon = _toDouble(item[0]);
        final lat = _toDouble(item[1]);
        if (lat != null && lon != null) {
          parsed.add([lat, lon]);
        }
      }
    }
    if (parsed.isEmpty) return null;

    final center = _computeCenter(parsed);
    final props = feature['properties'] is Map
        ? Map<String, dynamic>.from(feature['properties'] as Map)
        : const <String, dynamic>{};

    return ConstructionSite(
      id: props['id']?.toString() ?? feature['id']?.toString() ?? '',
      type: props['type']?.toString(),
      subtype: props['subtype']?.toString(),
      description: props['description']?.toString(),
      street: props['street']?.toString(),
      direction: props['direction']?.toString(),
      reference: props['reference']?.toString(),
      startTime: _parseDateTime(props['starttime']),
      endTime: _parseDateTime(props['endtime']),
      lat: center[0],
      lon: center[1],
      coordinates: parsed,
    );
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  static List<double> _computeCenter(List<List<double>> coords) {
    double sumLat = 0;
    double sumLon = 0;
    for (final point in coords) {
      sumLat += point[0];
      sumLon += point[1];
    }
    return [sumLat / coords.length, sumLon / coords.length];
  }
}
