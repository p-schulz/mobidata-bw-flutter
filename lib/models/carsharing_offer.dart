class CarsharingOffer {
  final String id;
  final String provider;
  final String name;
  final double lat;
  final double lon;

  final String vehicleType;
  final bool isAvailable;
  final int? availableVehicles;

  CarsharingOffer({
    required this.id,
    required this.provider,
    required this.name,
    required this.lat,
    required this.lon,
    required this.vehicleType,
    required this.isAvailable,
    this.availableVehicles,
  });

  static CarsharingOffer? fromJson(Map<String, dynamic> j) {
    try {
      final lat = (j['lat'] ?? j['latitude']) as num?;
      final lon = (j['lon'] ?? j['longitude']) as num?;
      if (lat == null || lon == null) return null;

      final id = (j['id'] ?? j['station_id'] ?? '').toString();
      final provider =
          (j['provider'] ?? j['operator'] ?? 'Unbekannt').toString();
      final name =
          (j['name'] ?? j['station_name'] ?? 'CarSharing-Station').toString();
      final vehicleType = (j['vehicle_type'] ?? 'car').toString();
      final isAvailable = (j['is_available'] ?? j['available'] ?? true) as bool;
      final availableVehicles =
          (j['available_vehicles'] ?? j['num_vehicles']) as int?;

      return CarsharingOffer(
        id: id,
        provider: provider,
        name: name,
        lat: lat.toDouble(),
        lon: lon.toDouble(),
        vehicleType: vehicleType,
        isAvailable: isAvailable,
        availableVehicles: availableVehicles,
      );
    } catch (_) {
      return null;
    }
  }
}
