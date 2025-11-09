class ParkingSite {
  final String id;
  final String name;

  final double? lat;
  final double? lon;

  final int? totalSpaces;        // numberOfSpaces
  final int? availableSpaces;    // availableSpaces (total)
  final bool? isOpenNow;         // isOpenNow
  final bool? temporarilyClosed; // temporaryClosed
  final bool? freeParking;       // freeParking
  final String? roadName;        // name of the road
  final String? occupancyTrend;  // occupancyTrend
  final String? type;            // carPark, etc.
  final String? url;             // urlLinkAddress
  final DateTime? lastUpdate;    // lastUpdate

  /// state: 'free', 'full', 'closed', 'unknown'
  final String status;

  ParkingSite({
    required this.id,
    required this.name,
    required this.status,
    this.lat,
    this.lon,
    this.totalSpaces,
    this.availableSpaces,
    this.isOpenNow,
    this.temporarilyClosed,
    this.freeParking,
    this.roadName,
    this.occupancyTrend,
    this.type,
    this.url,
    this.lastUpdate,
  });

  static ParkingSite? fromJson(Map<String, dynamic> j) {
    try {
      double? lat;
      double? lon;
      String? roadName;

      // DATEX-II: locationAndDimension.coordinatesForDisplay.latitude/longitude
      final loc = j['locationAndDimension'];
      if (loc is Map<String, dynamic>) {
        final coords = loc['coordinatesForDisplay'];
        if (coords is Map<String, dynamic>) {
          lat = _toDouble(coords['latitude']);
          lon = _toDouble(coords['longitude']);
        }
        final road = loc['roadName'];
        if (road is String) {
          roadName = 'Unknown';
        }
      }

      // Fallback: GeoJSON geometry
      final geom = j['geometry'];
      if ((lat == null || lon == null) &&
          geom is Map<String, dynamic> &&
          geom['type'] == 'Point' &&
          geom['coordinates'] is List &&
          (geom['coordinates'] as List).length >= 2) {
        lon = _toDouble((geom['coordinates'] as List)[0]);
        lat = _toDouble((geom['coordinates'] as List)[1]);
      }

      lat ??= _toDouble(j['lat'] ?? j['latitude']);
      lon ??= _toDouble(j['lon'] ?? j['lng'] ?? j['longitude']);
      roadName = j['address']?.toString();

      if (lat == null || lon == null) {
        return null;
      }

      if (roadName == null) {
        roadName = 'Unknown';
      }

      final id = (j['_id'] ?? j['id'] ?? j['uuid'] ?? j['identifier'] ?? '')
          .toString();
      final name = (j['name'] ?? j['description'] ?? 'Parkplatz').toString();

      final totalSpaces =
      _toInt(j['numberOfSpaces'] ?? j['capacity'] ?? j['totalSpaces']);
      final availableSpaces = _toInt(j['availableSpaces']);
      final isOpenNow = j['isOpenNow'] is bool ? j['isOpenNow'] as bool : null;
      final temporarilyClosed = j['temporaryClosed'] is bool
          ? j['temporaryClosed'] as bool
          : null;
      final freeParking =
      j['freeParking'] is bool ? j['freeParking'] as bool : null;
      final occupancyTrend =
      j['occupancyTrend'] != null ? j['occupancyTrend'].toString() : null;
      final type = j['type']?.toString();
      final url = j['urlLinkAddress']?.toString();

      DateTime? lastUpdate;
      final lu = j['lastUpdate'];
      if (lu is String) {
        lastUpdate = DateTime.tryParse(lu);
      }

      // state
      final status = _deriveStatus(
        totalSpaces: totalSpaces,
        availableSpaces: availableSpaces,
        isOpenNow: isOpenNow,
        temporarilyClosed: temporarilyClosed,
      );

      return ParkingSite(
        id: id,
        name: name,
        lat: lat,
        lon: lon,
        totalSpaces: totalSpaces,
        availableSpaces: availableSpaces,
        isOpenNow: isOpenNow,
        temporarilyClosed: temporarilyClosed,
        freeParking: freeParking,
        roadName : roadName,
        occupancyTrend: occupancyTrend,
        type: type,
        url: url,
        lastUpdate: lastUpdate,
        status: status,
      );
    } catch (_) {
      return null;
    }
  }

  static String _deriveStatus({
    int? totalSpaces,
    int? availableSpaces,
    bool? isOpenNow,
    bool? temporarilyClosed,
  }) {
    if (temporarilyClosed == true || isOpenNow == false) {
      return 'closed';
    }

    if (totalSpaces != null && availableSpaces != null) {
      if (availableSpaces > 0) {
        return 'free';
      }
      if (availableSpaces == 0 && totalSpaces > 0) {
        return 'full';
      }
    }

    return 'unknown';
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
      return int.tryParse(v);
    }
    return null;
  }
}
