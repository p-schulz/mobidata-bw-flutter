class CarsharingOffer {
  final String id;
  final String provider;
  final String name;
  final double lat;
  final double lon;

  final String vehicleType;
  final int availableVehicles;
  final bool isRentingAllowed;

  CarsharingOffer({
    required this.id,
    required this.provider,
    required this.name,
    required this.lat,
    required this.lon,
    required this.vehicleType,
    required this.availableVehicles,
    required this.isRentingAllowed,
  });

  static CarsharingOffer? fromJson(Map<String, dynamic> j) {
    try {
      final lat = j['lat'] ?? j['latitude'];
      final lon = j['lon'] ?? j['longitude'];
      if (lat == null || lon == null) return null;

      return CarsharingOffer(
        id: (j['station_id'] ?? j['id'] ?? '').toString(),
        provider: (j['provider'] ?? j['operator'] ?? 'unbekannt').toString(),
        name:
            (j['name'] ?? j['station_name'] ?? 'CarSharing-Station').toString(),
        lat: (lat as num).toDouble(),
        lon: (lon as num).toDouble(),
        vehicleType: (j['vehicle_type'] ?? 'car').toString(),
        availableVehicles: (j['num_vehicles_available'] ??
            j['available_vehicles'] ??
            0) as int,
        isRentingAllowed: (j['is_renting_allowed'] ?? true) as bool,
      );
    } catch (_) {
      return null;
    }
  }
}
