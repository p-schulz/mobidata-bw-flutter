class ScooterVehicle {
  final String id;
  final String provider;
  final String vehicleType;
  final double lat;
  final double lon;
  final bool isReserved;
  final bool isDisabled;
  final double? rangeMeters;
  final double? batteryPercent;

  ScooterVehicle({
    required this.id,
    required this.provider,
    required this.vehicleType,
    required this.lat,
    required this.lon,
    required this.isReserved,
    required this.isDisabled,
    this.rangeMeters,
    this.batteryPercent,
  });

  static ScooterVehicle? fromJson(Map<String, dynamic> json) {
    try {
      final lat = json['lat'];
      final lon = json['lon'];
      if (lat == null || lon == null) return null;

      return ScooterVehicle(
        id: (json['bike_id'] ?? json['id'] ?? '').toString(),
        provider: (json['provider'] ?? json['operator'] ?? 'unbekannt')
            .toString(),
        vehicleType:
            (json['vehicle_type'] ?? json['vehicleType'] ?? 'Scooter')
                .toString(),
        lat: (lat as num).toDouble(),
        lon: (lon as num).toDouble(),
        isReserved: (json['is_reserved'] ?? json['isReserved'] ?? false) as bool,
        isDisabled:
            (json['is_disabled'] ?? json['isDisabled'] ?? false) as bool,
        rangeMeters: (json['current_range_meters'] ??
                json['currentRangeMeters'] ??
                json['range']) is num
            ? (json['current_range_meters'] ??
                    json['currentRangeMeters'] ??
                    json['range']) *
                1.0
            : null,
        batteryPercent: (json['current_fuel_percent'] ??
                json['currentFuelPercent'] ??
                json['battery']) is num
            ? (json['current_fuel_percent'] ??
                    json['currentFuelPercent'] ??
                    json['battery']) *
                1.0
            : null,
      );
    } catch (_) {
      return null;
    }
  }
}
