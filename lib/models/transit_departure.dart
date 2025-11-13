class TransitDeparture {
  final String id;
  final String routeShortName;
  final String? routeLongName;
  final String? routeType;
  final String? headsign;
  final String? stopName;
  final String? stationName;
  final String? platform;
  final String? stopId;
  final int? stopSequence;
  final DateTime? scheduledDeparture;
  final DateTime? realtimeDeparture;
  final int? delayMinutes;

  TransitDeparture({
    required this.id,
    required this.routeShortName,
    this.routeLongName,
    this.routeType,
    this.headsign,
    this.stopName,
    this.stationName,
    this.platform,
    this.stopId,
    this.stopSequence,
    this.scheduledDeparture,
    this.realtimeDeparture,
    this.delayMinutes,
  });

  static TransitDeparture? fromJson(Map<String, dynamic> json) {
    final id = json['arrival_departure_id']?.toString();
    final routeShortName = json['route_short_name']?.toString() ??
        json['route_long_name']?.toString() ??
        '';
    if (id == null || id.isEmpty || routeShortName.isEmpty) return null;

    final dateStr = json['date']?.toString();
    final scheduled =
        _mergeDateAndTime(dateStr, json['departure_time']?.toString());
    final realtime =
        _parseDateTime(json['t_departure']?.toString()) ?? scheduled;

    int? delayMinutes;
    if (scheduled != null && realtime != null) {
      delayMinutes = realtime.difference(scheduled).inMinutes;
    }

    final stationName = json['station_name']?.toString();
    final stopName = json['stop_name']?.toString();
    String? platform = json['platform_code']?.toString();
    if ((platform == null || platform.isEmpty) &&
        stopName != null &&
        stationName != null &&
        stopName.trim().toLowerCase() != stationName.trim().toLowerCase()) {
      platform = stopName;
    } else if ((platform == null || platform.isEmpty) &&
        json['stop_headsign'] != null) {
      platform = json['stop_headsign'].toString();
    }

    return TransitDeparture(
      id: id,
      routeShortName: routeShortName,
      routeLongName: json['route_long_name']?.toString(),
      routeType: json['route_type']?.toString(),
      headsign: json['trip_headsign']?.toString(),
      stopName: stopName,
      stationName: stationName,
      platform: platform,
      stopId: json['stop_id']?.toString(),
      stopSequence: int.tryParse(json['stop_sequence']?.toString() ?? ''),
      scheduledDeparture: scheduled,
      realtimeDeparture: realtime,
      delayMinutes: delayMinutes,
    );
  }

  static DateTime? _mergeDateAndTime(String? dateStr, String? timeStr) {
    if (dateStr == null || timeStr == null) return null;
    DateTime? date;
    if (dateStr.contains('-')) {
      date = DateTime.tryParse(dateStr);
    } else if (dateStr.length == 8) {
      final year = int.tryParse(dateStr.substring(0, 4));
      final month = int.tryParse(dateStr.substring(4, 6));
      final day = int.tryParse(dateStr.substring(6, 8));
      if (year != null && month != null && day != null) {
        date = DateTime(year, month, day);
      }
    }
    if (date == null) return null;
    var resultDate = date;

    final parts = timeStr.split(':');
    if (parts.length < 2) return null;
    int hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    final second = parts.length > 2 ? int.tryParse(parts[2]) ?? 0 : 0;

    while (hour >= 24) {
      resultDate = resultDate.add(const Duration(days: 1));
      hour -= 24;
    }

    return DateTime(
      resultDate.year,
      resultDate.month,
      resultDate.day,
      hour,
      minute,
      second,
    );
  }

  static DateTime? _parseDateTime(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }
}
