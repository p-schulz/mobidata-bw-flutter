class ParkingSite {
  final String id;
  final String name;

  final double? lat;
  final double? lon;

  final int? totalSpaces; // numberOfSpaces
  final int? availableSpaces; // availableSpaces (total)
  final bool? isOpenNow; // isOpenNow
  final bool? temporarilyClosed; // temporaryClosed
  final bool? freeParking; // freeParking
  final String? roadName; // name of the road
  final String? occupancyTrend; // occupancyTrend
  final String? type; // carPark, etc.
  final String? url; // urlLinkAddress
  final DateTime? lastUpdate; // lastUpdate
  final String? openingHours; // OSM opening_hours string

  final bool hasRealtimeData;
  final int? realtimeCapacity;
  final int? realtimeFreeCapacity;
  final String? realtimeOpeningStatus;
  final DateTime? realtimeUpdatedAt;

  /// state: 'free', 'full', 'closed', 'unknown'
  final String status;

  ParkingSite({
    required this.id,
    required this.name,
    required this.status,
    required this.hasRealtimeData,
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
    this.openingHours,
    this.realtimeCapacity,
    this.realtimeFreeCapacity,
    this.realtimeOpeningStatus,
    this.realtimeUpdatedAt,
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
      final temporarilyClosed =
          j['temporaryClosed'] is bool ? j['temporaryClosed'] as bool : null;
      final freeParking =
          j['freeParking'] is bool ? j['freeParking'] as bool : null;
      final occupancyTrend =
          j['occupancyTrend'] != null ? j['occupancyTrend'].toString() : null;
      final type = j['type']?.toString();
      final url = j['urlLinkAddress']?.toString();
      final openingHours = j['opening_hours']?.toString();
      final hasRealtimeData = j['has_realtime_data'] == true;
      final realtimeCapacity = _toInt(j['realtime_capacity']);
      final realtimeFreeCapacity = _toInt(j['realtime_free_capacity']);
      final realtimeOpeningStatus = j['realtime_opening_status']?.toString();

      DateTime? lastUpdate;
      final lu = j['lastUpdate'];
      if (lu is String) {
        lastUpdate = DateTime.tryParse(lu);
      }

      DateTime? realtimeUpdatedAt;
      final ru = j['realtime_updated_at'] ?? j['realtime_data_updated_at'];
      if (ru is String) {
        realtimeUpdatedAt = DateTime.tryParse(ru);
      }

      // state
      final status = _deriveStatus(
        hasRealtimeData: hasRealtimeData,
        realtimeFreeCapacity: realtimeFreeCapacity,
        realtimeOpeningStatus: realtimeOpeningStatus,
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
        roadName: roadName,
        occupancyTrend: occupancyTrend,
        type: type,
        url: url,
        lastUpdate: lastUpdate,
        openingHours: openingHours,
        hasRealtimeData: hasRealtimeData,
        realtimeCapacity: realtimeCapacity,
        realtimeFreeCapacity: realtimeFreeCapacity,
        realtimeOpeningStatus: realtimeOpeningStatus,
        realtimeUpdatedAt: realtimeUpdatedAt,
        status: status,
      );
    } catch (_) {
      return null;
    }
  }

  int? get capacity {
    if (hasRealtimeData && realtimeCapacity != null) {
      return realtimeCapacity;
    }
    return totalSpaces;
  }

  int? get freeCapacity {
    if (hasRealtimeData && realtimeFreeCapacity != null) {
      return realtimeFreeCapacity;
    }
    return availableSpaces;
  }

  bool? get isCurrentlyOpen {
    if (hasRealtimeData && realtimeOpeningStatus != null) {
      final opening = realtimeOpeningStatus!.toLowerCase();
      if (opening.contains('open')) return true;
      if (opening.contains('clos')) return false;
    }
    return isOpenNow;
  }

  static String _deriveStatus({
    required bool hasRealtimeData,
    int? realtimeFreeCapacity,
    String? realtimeOpeningStatus,
    int? totalSpaces,
    int? availableSpaces,
    bool? isOpenNow,
    bool? temporarilyClosed,
  }) {
    if (hasRealtimeData) {
      final opening = realtimeOpeningStatus?.toLowerCase();
      if (opening != null) {
        if (opening.contains('close')) {
          return 'closed';
        }
        if (opening.contains('open') && realtimeFreeCapacity != null) {
          return realtimeFreeCapacity > 0 ? 'free' : 'full';
        }
      }

      if (realtimeFreeCapacity != null) {
        if (realtimeFreeCapacity > 0) return 'free';
        if (realtimeFreeCapacity == 0) return 'full';
      }
    }

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
