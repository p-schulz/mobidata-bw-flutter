class BikesharingStation {
  final String id;
  final String provider;
  final String name;
  final double lat;
  final double lon;
  final int availableVehicles;
  final bool isRentingAllowed;

  BikesharingStation({
    required this.id,
    required this.provider,
    required this.name,
    required this.lat,
    required this.lon,
    required this.availableVehicles,
    required this.isRentingAllowed,
  });

  static BikesharingStation? fromJson(Map<String, dynamic> json) {
    try {
      final lat = json['lat'] ?? json['latitude'];
      final lon = json['lon'] ?? json['longitude'];
      if (lat == null || lon == null) return null;

      return BikesharingStation(
        id: (json['station_id'] ?? json['id'] ?? '').toString(),
        provider: (json['provider'] ?? json['operator'] ?? 'unbekannt')
            .toString(),
        name: (json['name'] ?? json['station_name'] ?? 'Station').toString(),
        lat: (lat as num).toDouble(),
        lon: (lon as num).toDouble(),
        availableVehicles:
            (json['available_vehicles'] ?? json['num_vehicles_available'] ?? 0)
                as int,
        isRentingAllowed:
            (json['is_renting_allowed'] ?? json['is_renting'] ?? true) as bool,
      );
    } catch (_) {
      return null;
    }
  }
}
