class ParkingSite {
  final String id;
  final String name;
  final double? lat;
  final double? lon;
  final int? capacity;
  final String? state;

  ParkingSite({
    required this.id,
    required this.name,
    required this.lat,
    required this.lon,
    this.capacity,
    this.state,
  });

  static ParkingSite? fromJson(Map<String, dynamic> j) {
    try {
      double? lat;
      double? lon;

      final geom = j['geometry'];

      // GeoJSON
      if (geom is Map && geom['type'] == 'Point') {
        final coords = geom['coordinates'];
        if (coords is List && coords.length >= 2) {
          lon = (coords[0] as num).toDouble();
          lat = (coords[1] as num).toDouble();
        }
      }

      // einfache Felder lat/lon
      lat ??= _toDouble(j['lat'] ?? j['latitude']);
      lon ??= _toDouble(j['lon'] ?? j['lng'] ?? j['longitude']);

      if (lat == null || lon == null) {
        return null;
      }

      final id = (j['id'] ?? j['uuid'] ?? j['identifier'] ?? '').toString();
      final name = (j['name'] ?? j['title'] ?? 'Parkplatz').toString();

      final capacity = _toInt(j['capacity'] ?? j['max_capacity']);
      final state = j['state']?.toString() ?? j['status']?.toString();

      return ParkingSite(
        id: id,
        name: name,
        lat: lat,
        lon: lon,
        capacity: capacity,
        state: state,
      );
    } catch (e) {
      // debug ausgabe?
      return null;
    }
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) {
      return double.tryParse(v.replaceAll(',', '.'));
    }
    return null;
  }

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) {
      final parsed = int.tryParse(v);
      return parsed;
    }
    return null;
  }
}
