class ParkingSpot {
  final String id;
  final String name;
  final double lat;
  final double lon;
  final String? address;
  final String? type;
  final String? purpose;
  final String? realtimeStatus;
  final bool hasRealtimeData;
  final DateTime? staticDataUpdatedAt;
  final DateTime? realtimeDataUpdatedAt;
  final List<String> restrictions;
  final List<String> restrictedTo;

  ParkingSpot({
    required this.id,
    required this.name,
    required this.lat,
    required this.lon,
    required this.hasRealtimeData,
    this.address,
    this.type,
    this.purpose,
    this.realtimeStatus,
    this.staticDataUpdatedAt,
    this.realtimeDataUpdatedAt,
    this.restrictions = const [],
    this.restrictedTo = const [],
  });

  static ParkingSpot? fromJson(Map<String, dynamic> json) {
    try {
      final lat = _toDouble(json['lat']);
      final lon = _toDouble(json['lon']);
      if (lat == null || lon == null) return null;

      final id =
          (json['_id'] ?? json['id'] ?? json['original_uid'] ?? '').toString();
      if (id.isEmpty) return null;

      final name = (json['name'] ?? 'Parkplatz').toString();
      final address = json['address']?.toString();
      final type = json['type']?.toString();
      final purpose = json['purpose']?.toString();
      final realtimeStatus = json['realtime_status']?.toString();
      final hasRealtimeData = json['has_realtime_data'] is bool
          ? json['has_realtime_data'] as bool
          : false;
      final staticDataUpdatedAt = _toDate(json['static_data_updated_at']);
      final realtimeDataUpdatedAt = _toDate(json['realtime_data_updated_at']);

      final restrictions = _stringList(json['restrictions']);
      final restrictedTo = _stringList(json['restricted_to']);

      return ParkingSpot(
        id: id,
        name: name,
        lat: lat,
        lon: lon,
        address: address,
        type: type,
        purpose: purpose,
        realtimeStatus: realtimeStatus,
        hasRealtimeData: hasRealtimeData,
        staticDataUpdatedAt: staticDataUpdatedAt,
        realtimeDataUpdatedAt: realtimeDataUpdatedAt,
        restrictions: restrictions,
        restrictedTo: restrictedTo,
      );
    } catch (_) {
      return null;
    }
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value.replaceAll(',', '.'));
    }
    return null;
  }

  static DateTime? _toDate(dynamic value) {
    if (value is String) return DateTime.tryParse(value);
    if (value is DateTime) return value;
    return null;
  }

  static List<String> _stringList(dynamic value) {
    if (value is List) {
      return value
          .map((e) {
            if (e is String) return e;
            if (e is Map && e['type'] is String) {
              return e['type'] as String;
            }
            return e?.toString();
          })
          .whereType<String>()
          .toList();
    }
    return const [];
  }
}
