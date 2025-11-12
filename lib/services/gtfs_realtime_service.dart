import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fixnum/fixnum.dart';
import 'package:gtfs_realtime_bindings/gtfs_realtime_bindings.dart';

class GtfsRealtimeService {
  GtfsRealtimeService._internal();

  static final GtfsRealtimeService instance = GtfsRealtimeService._internal();

  static const _tripUpdatesUrl =
      'https://api.mobidata-bw.de/gtfs/v2/gtfs-rt/tripupdates';
  static const _vehiclePositionsUrl =
      'https://api.mobidata-bw.de/gtfs/v2/gtfs-rt/vehiclepositions';
  static const _defaultInterval = Duration(seconds: 20);

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      responseType: ResponseType.bytes,
      headers: const {'Accept': 'application/x-protobuf'},
    ),
  );

  Timer? _pollTimer;
  Duration _pollInterval = _defaultInterval;
  DateTime? _lastUpdated;
  Uint8List? _lastPayload;
  bool _isRefreshing = false;
  Object? _lastError;

  final Map<String, TripRealtimeData> _tripUpdates = {};

  DateTime? get lastUpdated => _lastUpdated;
  Object? get lastError => _lastError;
  bool get isPolling => _pollTimer != null;

  void startPolling({Duration interval = _defaultInterval}) {
    _pollInterval = interval;
    _pollTimer ??= Timer.periodic(_pollInterval, (_) {
      refresh();
    });
    refresh(force: true);
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> refresh({bool force = false}) async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    try {
      final response = await _dio.get<List<int>>(_tripUpdatesUrl);
      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) {
        return;
      }
      final payload = Uint8List.fromList(bytes);
      _parseTripUpdates(payload);
      _lastPayload = payload;
      _lastUpdated = DateTime.now();
      _lastError = null;
    } catch (e) {
      _lastError = e;
    } finally {
      _isRefreshing = false;
    }
  }

  StopRealtimeUpdate? getStopUpdate(
    String tripId, {
    int? stopSequence,
    String? stopId,
  }) {
    final trip = _tripUpdates[tripId];
    if (trip == null) return null;
    if (stopSequence != null) {
      final update = trip.stopSequenceUpdates[stopSequence];
      if (update != null) return update;
    }
    if (stopId != null) {
      final update = trip.stopIdUpdates[stopId];
      if (update != null) return update;
    }
    return trip.globalUpdate;
  }

  void _parseTripUpdates(Uint8List payload) {
    final feed = FeedMessage.fromBuffer(payload);
    _tripUpdates.clear();
    for (final entity in feed.entity) {
      if (!entity.hasTripUpdate()) continue;
      final tripUpdate = entity.tripUpdate;
      if (!tripUpdate.hasTrip()) continue;
      final tripId = tripUpdate.trip.tripId;
      if (tripId.isEmpty) continue;
      final tripData = TripRealtimeData(tripId: tripId);

      if (tripUpdate.hasDelay()) {
        tripData.globalUpdate = StopRealtimeUpdate(
          tripId: tripId,
          arrivalDelay: tripUpdate.delay,
          departureDelay: tripUpdate.delay,
        );
      }

      for (final stopUpdate in tripUpdate.stopTimeUpdate) {
        final update = StopRealtimeUpdate(
          tripId: tripId,
          stopSequence: stopUpdate.stopSequence,
          stopId: stopUpdate.stopId,
          arrivalDelay:
              stopUpdate.hasArrival() ? stopUpdate.arrival.delay : null,
          departureDelay:
              stopUpdate.hasDeparture() ? stopUpdate.departure.delay : null,
          arrivalTime: stopUpdate.hasArrival()
              ? _unixToDateTime(_intFromFixnum(stopUpdate.arrival.time))
              : null,
          departureTime: stopUpdate.hasDeparture()
              ? _unixToDateTime(_intFromFixnum(stopUpdate.departure.time))
              : null,
        );
        if (update.stopSequence != null) {
          tripData.stopSequenceUpdates[update.stopSequence!] = update;
        }
        if (update.stopId != null && update.stopId!.isNotEmpty) {
          tripData.stopIdUpdates[update.stopId!] = update;
        }
      }

      _tripUpdates[tripId] = tripData;
    }
  }

  DateTime? _unixToDateTime(int? seconds) {
    if (seconds == null || seconds <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true)
        .toLocal();
  }

  int? _intFromFixnum(Int64? value) => value?.toInt();

  Future<List<VehiclePositionData>> fetchVehiclePositions({
    String? tripId,
  }) async {
    final res = await _dio.get<List<int>>(_vehiclePositionsUrl);
    final bytes = res.data;
    if (bytes == null || bytes.isEmpty) return const [];
    final feed = FeedMessage.fromBuffer(Uint8List.fromList(bytes));
    final positions = <VehiclePositionData>[];
    for (final entity in feed.entity) {
      if (!entity.hasVehicle()) continue;
      final vehicle = entity.vehicle;
      final vid = vehicle.vehicle;
      final trip = vehicle.trip;
      if (tripId != null && trip.tripId != tripId) continue;
      if (!vehicle.hasPosition()) continue;
      positions.add(
        VehiclePositionData(
          tripId: trip.tripId,
          routeId: trip.routeId,
          vehicleId: vid.hasId() ? vid.id : null,
          lat: vehicle.position.latitude,
          lon: vehicle.position.longitude,
          bearing:
              vehicle.position.hasBearing() ? vehicle.position.bearing : null,
          lastUpdate: vehicle.hasTimestamp()
              ? _unixToDateTime(_intFromFixnum(vehicle.timestamp))
              : null,
        ),
      );
    }
    return positions;
  }
}

class TripRealtimeData {
  TripRealtimeData({required this.tripId});

  final String tripId;
  final Map<int, StopRealtimeUpdate> stopSequenceUpdates = {};
  final Map<String, StopRealtimeUpdate> stopIdUpdates = {};
  StopRealtimeUpdate? globalUpdate;
}

class StopRealtimeUpdate {
  StopRealtimeUpdate({
    required this.tripId,
    this.stopSequence,
    this.stopId,
    this.arrivalDelay,
    this.departureDelay,
    this.arrivalTime,
    this.departureTime,
  });

  final String tripId;
  final int? stopSequence;
  final String? stopId;
  final int? arrivalDelay;
  final int? departureDelay;
  final DateTime? arrivalTime;
  final DateTime? departureTime;

  int? get bestDelay => departureDelay ?? arrivalDelay;
  DateTime? get bestTime => departureTime ?? arrivalTime;
}

class VehiclePositionData {
  VehiclePositionData({
    required this.tripId,
    required this.routeId,
    required this.lat,
    required this.lon,
    this.vehicleId,
    this.bearing,
    this.lastUpdate,
  });

  final String tripId;
  final String? routeId;
  final double lat;
  final double lon;
  final String? vehicleId;
  final double? bearing;
  final DateTime? lastUpdate;
}
