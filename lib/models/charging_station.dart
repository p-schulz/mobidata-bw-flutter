class ChargingStation {
  final String id;
  final String name;
  final String? address;
  final String? city;
  final double lat;
  final double lon;
  final String? operatorName;
  final String? status;
  final String? parkingType;
  final String? lastUpdated;
  final int connectorCount;
  final int? maxPowerKw;

  ChargingStation({
    required this.id,
    required this.name,
    required this.lat,
    required this.lon,
    this.address,
    this.city,
    this.operatorName,
    this.status,
    this.parkingType,
    this.lastUpdated,
    this.connectorCount = 0,
    this.maxPowerKw,
  });

  static ChargingStation? fromJson(Map<String, dynamic> json) {
    final coords = json['coordinates'];
    double? lat;
    double? lon;
    if (coords is Map<String, dynamic>) {
      lat = _toDouble(coords['lat']) ?? _toDouble(coords['latitude']);
      lon = _toDouble(coords['lon']) ?? _toDouble(coords['longitude']);
    }
    if (lat == null || lon == null) return null;

    final evses = json['evses'];
    String? status;
    int connectorCount = 0;
    int? maxPower;
    if (evses is List) {
      for (final evse in evses) {
        if (evse is Map<String, dynamic>) {
          status ??= evse['status']?.toString();
          final connectors = evse['connectors'];
          if (connectors is List) {
            connectorCount += connectors.length;
            for (final conn in connectors) {
              if (conn is Map<String, dynamic>) {
                final power = conn['max_electric_power'];
                final asInt = power is num ? power.toInt() : int.tryParse('$power');
                if (asInt != null) {
                  if ((maxPower ?? 0) < asInt) {
                    maxPower = asInt;
                  }
                }
              }
            }
          }
        }
      }
    }

    return ChargingStation(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Ladestation',
      lat: lat,
      lon: lon,
      address: json['address']?.toString(),
      city: json['city']?.toString(),
      operatorName: json['operator'] is Map
          ? (json['operator']['name']?.toString())
          : json['operator']?.toString(),
      status: status,
      parkingType: json['parking_type']?.toString(),
      lastUpdated: json['last_updated']?.toString(),
      connectorCount: connectorCount,
      maxPowerKw: maxPower != null ? (maxPower / 1000).round() : null,
    );
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}
