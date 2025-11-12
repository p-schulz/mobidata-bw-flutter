class TransitStop {
  final String id;
  final String name;
  final double lat;
  final double lon;
  final String? description;
  final String? parentStationId;

  TransitStop({
    required this.id,
    required this.name,
    required this.lat,
    required this.lon,
    this.description,
    this.parentStationId,
  });

  static TransitStop? fromJson(Map<String, dynamic> json) {
    final loc = json['stop_loc'];
    double? lat;
    double? lon;

    if (loc is Map<String, dynamic>) {
      final coords = loc['coordinates'];
      if (coords is List && coords.length >= 2) {
        lon = _toDouble(coords[0]);
        lat = _toDouble(coords[1]);
      }
    } else if (loc is String) {
      final match = RegExp(r'POINT\s*\((-?\d+(?:\.\d+)?)\s+(-?\d+(?:\.\d+)?)\)')
          .firstMatch(loc);
      if (match != null) {
        lon = double.tryParse(match.group(1)!);
        lat = double.tryParse(match.group(2)!);
      }
    }

    if (lat == null || lon == null) return null;

    final id = json['stop_id']?.toString();
    final name = json['stop_name']?.toString();
    if (id == null || id.isEmpty || name == null || name.isEmpty) return null;

    return TransitStop(
      id: id,
      name: name,
      lat: lat,
      lon: lon,
      description: json['stop_desc']?.toString(),
      parentStationId: json['parent_station']?.toString(),
    );
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}
