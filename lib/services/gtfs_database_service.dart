import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_map/flutter_map.dart' show LatLngBounds;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/transit_departure.dart';
import '../models/transit_stop.dart';
import 'cache_service.dart';

class GtfsDatabaseService {
  GtfsDatabaseService._internal();

  static final GtfsDatabaseService instance = GtfsDatabaseService._internal();

  static const _dbName = 'gtfs_static.db';
  static const _gtfsVersion = '20251008-stopsV2';
  static const _gtfsZipUrl =
      'https://mobidata-bw.de/gtfs-historisierung/mit_linienverlauf/2025/20251008/bwgesamt.zip'; // aktuelle Version, Stand 12.11.2025
  static const _metadataVersionKey = 'gtfs_version';

  Database? _db;
  bool _initializing = false;
  final ValueNotifier<double?> downloadProgress = ValueNotifier<double?>(null);
  String? _dbPath;
  String? get databasePath => _dbPath;

  Future<Database> get database async {
    if (_db == null) {
      await init();
    }
    return _db!;
  }

  Future<void> init({
    bool useBundledSeed = true,
    bool allowDownload = true,
  }) async {
    if (_db != null || _initializing) return;
    _initializing = true;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final dbPath = p.join(dir.path, _dbName);
      _dbPath = dbPath;
      final dbFile = File(dbPath);

      if (!await dbFile.exists()) {
        var copied = false;
        if (useBundledSeed) {
          copied = await _tryCopyBundledSeed(dbPath);
        }
        if (!copied) {
          if (!allowDownload) {
            throw Exception(
                'Keine GTFS-Seed-Datei gefunden und Download deaktiviert.');
          }
          _db = await _openDatabase(dbPath, resetSchema: true);
          await _importGtfsData();
          return;
        }
      }

      _db = await _openDatabase(dbPath);
      if (allowDownload) {
        await _ensureData();
      }
    } finally {
      _initializing = false;
    }
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS metadata (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');

    await _createStopsStructure(db);

    await db.execute('''
      CREATE TABLE IF NOT EXISTS routes (
        route_id TEXT PRIMARY KEY,
        short_name TEXT,
        long_name TEXT,
        type INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS trips (
        trip_id TEXT PRIMARY KEY,
        route_id TEXT,
        service_id TEXT,
        headsign TEXT,
        direction_id INTEGER,
        shape_id TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS stop_times (
        trip_id TEXT,
        arrival_time TEXT,
        departure_time TEXT,
        stop_id TEXT,
        stop_sequence INTEGER,
        pickup_type INTEGER,
        drop_off_type INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS calendar (
        service_id TEXT PRIMARY KEY,
        monday INTEGER,
        tuesday INTEGER,
        wednesday INTEGER,
        thursday INTEGER,
        friday INTEGER,
        saturday INTEGER,
        sunday INTEGER,
        start_date TEXT,
        end_date TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS calendar_dates (
        service_id TEXT,
        date TEXT,
        exception_type INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS service_days (
        service_id TEXT,
        service_date TEXT,
        PRIMARY KEY (service_id, service_date)
      )
    ''');

    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_stop_times_stop ON stop_times(stop_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_stop_times_trip ON stop_times(trip_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_trips_route ON trips(route_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_trips_service ON trips(service_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_calendar_service ON calendar(service_id)');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS stop_route_types (
        stop_id TEXT,
        route_type INTEGER,
        PRIMARY KEY (stop_id, route_type)
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_stop_route_stop ON stop_route_types(stop_id)');
  }

  Future<void> _createStopsStructure(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS stops (
        stop_id TEXT PRIMARY KEY,
        stop_name TEXT NOT NULL,
        stop_desc TEXT,
        stop_lat REAL NOT NULL,
        stop_lon REAL NOT NULL,
        location_type INTEGER DEFAULT 0,
        parent_station TEXT,
        wheelchair_boarding INTEGER DEFAULT 0
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_stops_lat_lon ON stops(stop_lat, stop_lon)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_stops_name_nocase ON stops(stop_name COLLATE NOCASE)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_stops_parent ON stops(parent_station)');
  }

  Future<void> _ensureData() async {
    final db = _db!;
    final currentVersion = await _getMetadata(_metadataVersionKey);
    final needsImport = currentVersion != _gtfsVersion;
    final existingCount = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM stops'),
        ) ??
        0;
    final hasStops = existingCount > 0;
    if (!needsImport && hasStops) {
      return;
    }
    await _importGtfsData();
  }

  Future<List<TransitStop>> fetchStopsInBounds({
    required LatLngBounds bounds,
    bool includeStops = true,
    int limit = 8000,
    Set<int>? allowedRouteTypes,
  }) async {
    if (_db == null) {
      await init();
    }
    final db = _db!;
    final minLat = bounds.south;
    final maxLat = bounds.north;
    final minLon = bounds.west;
    final maxLon = bounds.east;
    final args = <Object>[minLat, maxLat, minLon, maxLon];
    var where = 'stop_lat BETWEEN ? AND ? AND stop_lon BETWEEN ? AND ?';
    if (!includeStops) {
      where += ' AND (location_type = 1 OR location_type IS NULL)';
    }
    if (allowedRouteTypes != null && allowedRouteTypes.isNotEmpty) {
      final placeholders = List.filled(allowedRouteTypes.length, '?').join(',');
      where +=
          ' AND stop_id IN (SELECT stop_id FROM stop_route_types WHERE route_type IN ($placeholders))';
      args.addAll(allowedRouteTypes);
    }
    final rows = await db.query(
      'stops',
      columns: [
        'stop_id',
        'stop_name',
        'stop_desc',
        'stop_lat',
        'stop_lon',
        'parent_station',
        'location_type',
        'wheelchair_boarding',
      ],
      where: where,
      whereArgs: args,
      limit: limit,
    );
    return rows.map(TransitStop.fromDbRow).whereType<TransitStop>().toList();
  }

  Future<List<StaticGtfsDeparture>> fetchUpcomingDeparturesForStop(
    String stopId, {
    DateTime? from,
    Duration horizon = const Duration(hours: 2),
    int limit = 40,
  }) async {
    if (_db == null) {
      await init();
    }
    final db = _db!;
    final now = (from ?? DateTime.now()).toLocal();
    final windowStart = now.subtract(const Duration(minutes: 1));
    final windowEnd = now.add(horizon);

    final dateStrings = <String>{
      _formatDateLocal(windowStart),
      _formatDateLocal(windowEnd),
    }.toList();

    final placeholders = dateStrings.map((_) => '?').join(',');
    final sql = '''
      SELECT st.trip_id, st.stop_id, st.stop_sequence, st.arrival_time, st.departure_time,
             t.service_id, t.route_id, t.headsign, t.direction_id,
             r.short_name, r.long_name, r.type,
             sd.service_date
      FROM stop_times st
      JOIN trips t ON t.trip_id = st.trip_id
      JOIN routes r ON r.route_id = t.route_id
      JOIN service_days sd ON sd.service_id = t.service_id
      WHERE st.stop_id = ?
        AND sd.service_date IN ($placeholders)
      ORDER BY sd.service_date, st.departure_time
      LIMIT 1200
    ''';

    final rows = await db.rawQuery(sql, [stopId, ...dateStrings]);
    final departures = <StaticGtfsDeparture>[];
    for (final row in rows) {
      final serviceDate = row['service_date'] as String?;
      final departureTime =
          (row['departure_time'] ?? row['arrival_time']) as String?;
      final scheduled = _combineServiceDateAndTime(serviceDate, departureTime);
      if (scheduled == null) continue;
      if (scheduled.isBefore(windowStart) || scheduled.isAfter(windowEnd)) {
        continue;
      }
      departures.add(
        StaticGtfsDeparture(
          tripId: row['trip_id'] as String,
          serviceId: row['service_id'] as String?,
          stopId: row['stop_id'] as String,
          stopSequence: (row['stop_sequence'] as int?) ??
              int.tryParse((row['stop_sequence'] ?? '').toString()),
          scheduledDeparture: scheduled,
          routeShortName: row['short_name'] as String?,
          routeLongName: row['long_name'] as String?,
          headsign: row['headsign'] as String?,
          routeType: (row['type'] as int?) ??
              int.tryParse((row['type'] ?? '').toString()),
        ),
      );
    }

    departures.sort((a, b) {
      final aTime =
          a.scheduledDeparture ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime =
          b.scheduledDeparture ?? DateTime.fromMillisecondsSinceEpoch(0);
      return aTime.compareTo(bTime);
    });

    if (departures.length > limit) {
      return departures.take(limit).toList(growable: false);
    }
    return departures;
  }

  Future<void> _importGtfsData() async {
    final db = _db!;
    final tempDir = await getTemporaryDirectory();
    final zipPath = p.join(tempDir.path, 'bw_gtfs.zip');

    await _downloadZip(zipPath);
    final archiveBytes = await File(zipPath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(archiveBytes);
    final fileMap = <String, ArchiveFile>{};
    for (final file in archive) {
      if (!file.isFile) continue;
      final key = p.basename(file.name).toLowerCase();
      fileMap[key] = file;
    }

    await db.transaction((txn) async {
      await _clearAll(txn);
      await _createStopsStructure(txn);
      final stopsFile = await _materialize(fileMap['stops.txt'], tempDir);
      final routesFile = await _materialize(fileMap['routes.txt'], tempDir);
      final tripsFile = await _materialize(fileMap['trips.txt'], tempDir);
      final stopTimesFile =
          await _materialize(fileMap['stop_times.txt'], tempDir);
      final calendarFile = await _materialize(fileMap['calendar.txt'], tempDir);
      final calendarDatesFile =
          await _materialize(fileMap['calendar_dates.txt'], tempDir);

      if (stopsFile != null) {
        await _importStops(txn, stopsFile);
      }
      if (routesFile != null) {
        await _importRoutes(txn, routesFile);
      }
      if (tripsFile != null) {
        await _importTrips(txn, tripsFile);
      }
      if (stopTimesFile != null) {
        await _importStopTimes(txn, stopTimesFile);
      }
      if (calendarFile != null) {
        await _importCalendar(txn, calendarFile);
      }
      if (calendarDatesFile != null) {
        await _importCalendarDates(txn, calendarDatesFile);
      }

      await _buildServiceDays(txn);
      await _buildStopRouteTypes(txn);
      await _setMetadata(_metadataVersionKey, _gtfsVersion, txn: txn);
    });

    for (final file in fileMap.values) {
      final tempFile =
          File(p.join(tempDir.path, p.basename(file.name).toLowerCase()));
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    }
    if (await File(zipPath).exists()) {
      await File(zipPath).delete();
    }
  }

  Future<void> _downloadZip(String targetPath) async {
    final dio = Dio();
    downloadProgress.value = 0.0;
    try {
      await dio.download(
        _gtfsZipUrl,
        targetPath,
        options:
            Options(responseType: ResponseType.bytes, followRedirects: true),
        onReceiveProgress: (received, total) {
          if (total <= 0) {
            downloadProgress.value = null;
          } else {
            downloadProgress.value = received / total;
          }
        },
      );
    } finally {
      downloadProgress.value = null;
    }
  }

  Future<File?> _materialize(
      ArchiveFile? archiveFile, Directory tempDir) async {
    if (archiveFile == null) return null;
    final filePath = p.join(tempDir.path, p.basename(archiveFile.name));
    final outFile = File(filePath);
    await outFile.parent.create(recursive: true);
    await outFile.writeAsBytes(archiveFile.content as List<int>, flush: true);
    return outFile;
  }

  Future<void> _clearAll(DatabaseExecutor db) async {
    for (final table in [
      'stop_times',
      'trips',
      'routes',
      'stops',
      'calendar',
      'calendar_dates',
      'service_days',
      'stop_route_types',
      'metadata',
    ]) {
      if (table == 'stops') {
        await db.execute('DROP TABLE IF EXISTS stops');
        await _createStopsStructure(db);
        continue;
      }
      if (table == 'stop_route_types') {
        await db.execute('DROP TABLE IF EXISTS stop_route_types');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS stop_route_types (
            stop_id TEXT,
            route_type INTEGER,
            PRIMARY KEY (stop_id, route_type)
          )
        ''');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_stop_route_stop ON stop_route_types(stop_id)');
        continue;
      }
      await db.delete(table);
    }
  }

  Stream<Map<String, String>> _readCsv(File file) async* {
    final stream = file.openRead();
    final lines = utf8.decoder
        .bind(stream)
        .transform(const LineSplitter())
        .asBroadcastStream();
    List<String>? headers;
    await for (final rawLine in lines) {
      final line = rawLine.trimRight();
      if (line.isEmpty) continue;
      final values = _parseCsvLine(line);
      if (headers == null) {
        headers = values
            .map((e) => e.replaceAll('\ufeff', '').trim())
            .toList(growable: false);
        continue;
      }
      final row = <String, String>{};
      for (var i = 0; i < headers.length && i < values.length; i++) {
        row[headers[i]] = values[i];
      }
      yield row;
    }
  }

  Future<void> _importStops(DatabaseExecutor db, File file) async {
    var batch = db.batch();
    var count = 0;
    await for (final row in _readCsv(file)) {
      final lat = double.tryParse(row['stop_lat'] ?? '');
      final lon = double.tryParse(row['stop_lon'] ?? '');
      batch.insert(
        'stops',
        {
          'stop_id': row['stop_id'],
          'stop_name': row['stop_name'],
          'stop_desc': row['stop_desc'],
          'stop_lat': lat,
          'stop_lon': lon,
          'location_type': int.tryParse(row['location_type'] ?? ''),
          'parent_station': row['parent_station'],
          'wheelchair_boarding': int.tryParse(row['wheelchair_boarding'] ?? ''),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      if (++count >= 500) {
        await batch.commit(noResult: true);
        batch = db.batch();
        count = 0;
      }
    }
    if (count > 0) {
      await batch.commit(noResult: true);
    }
  }

  Future<void> _importRoutes(DatabaseExecutor db, File file) async {
    var batch = db.batch();
    var count = 0;
    await for (final row in _readCsv(file)) {
      batch.insert(
        'routes',
        {
          'route_id': row['route_id'],
          'short_name': row['route_short_name'],
          'long_name': row['route_long_name'],
          'type': int.tryParse(row['route_type'] ?? ''),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      if (++count >= 500) {
        await batch.commit(noResult: true);
        batch = db.batch();
        count = 0;
      }
    }
    if (count > 0) {
      await batch.commit(noResult: true);
    }
  }

  Future<void> _importTrips(DatabaseExecutor db, File file) async {
    var batch = db.batch();
    var count = 0;
    await for (final row in _readCsv(file)) {
      batch.insert(
        'trips',
        {
          'trip_id': row['trip_id'],
          'route_id': row['route_id'],
          'service_id': row['service_id'],
          'headsign': row['trip_headsign'],
          'direction_id': int.tryParse(row['direction_id'] ?? ''),
          'shape_id': row['shape_id'],
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      if (++count >= 500) {
        await batch.commit(noResult: true);
        batch = db.batch();
        count = 0;
      }
    }
    if (count > 0) {
      await batch.commit(noResult: true);
    }
  }

  Future<void> _importStopTimes(DatabaseExecutor db, File file) async {
    var batch = db.batch();
    var count = 0;
    await for (final row in _readCsv(file)) {
      batch.insert(
        'stop_times',
        {
          'trip_id': row['trip_id'],
          'arrival_time': row['arrival_time'],
          'departure_time': row['departure_time'],
          'stop_id': row['stop_id'],
          'stop_sequence': int.tryParse(row['stop_sequence'] ?? ''),
          'pickup_type': int.tryParse(row['pickup_type'] ?? ''),
          'drop_off_type': int.tryParse(row['drop_off_type'] ?? ''),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      if (++count >= 1000) {
        await batch.commit(noResult: true);
        batch = db.batch();
        count = 0;
      }
    }
    if (count > 0) {
      await batch.commit(noResult: true);
    }
  }

  Future<void> _importCalendar(DatabaseExecutor db, File file) async {
    var batch = db.batch();
    var count = 0;
    await for (final row in _readCsv(file)) {
      batch.insert(
        'calendar',
        {
          'service_id': row['service_id'],
          'monday': int.tryParse(row['monday'] ?? '') ?? 0,
          'tuesday': int.tryParse(row['tuesday'] ?? '') ?? 0,
          'wednesday': int.tryParse(row['wednesday'] ?? '') ?? 0,
          'thursday': int.tryParse(row['thursday'] ?? '') ?? 0,
          'friday': int.tryParse(row['friday'] ?? '') ?? 0,
          'saturday': int.tryParse(row['saturday'] ?? '') ?? 0,
          'sunday': int.tryParse(row['sunday'] ?? '') ?? 0,
          'start_date': row['start_date'],
          'end_date': row['end_date'],
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      if (++count >= 500) {
        await batch.commit(noResult: true);
        batch = db.batch();
        count = 0;
      }
    }
    if (count > 0) {
      await batch.commit(noResult: true);
    }
  }

  Future<void> _importCalendarDates(DatabaseExecutor db, File file) async {
    var batch = db.batch();
    var count = 0;
    await for (final row in _readCsv(file)) {
      batch.insert(
        'calendar_dates',
        {
          'service_id': row['service_id'],
          'date': row['date'],
          'exception_type': int.tryParse(row['exception_type'] ?? ''),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      if (++count >= 500) {
        await batch.commit(noResult: true);
        batch = db.batch();
        count = 0;
      }
    }
    if (count > 0) {
      await batch.commit(noResult: true);
    }
  }

  Future<void> _buildServiceDays(DatabaseExecutor db) async {
    await db.delete('service_days');
    final calendars = await db.query('calendar');
    var batch = db.batch();
    var pending = 0;

    for (final cal in calendars) {
      final start = _parseDate(cal['start_date'] as String?);
      final end = _parseDate(cal['end_date'] as String?);
      if (start == null || end == null) continue;
      var current = start;
      while (!current.isAfter(end)) {
        if (_isServiceRunning(cal, current.weekday)) {
          batch.insert(
            'service_days',
            {
              'service_id': cal['service_id'],
              'service_date': _formatDate(current),
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          if (++pending >= 500) {
            await batch.commit(noResult: true);
            batch = db.batch();
            pending = 0;
          }
        }
        current = current.add(const Duration(days: 1));
      }
    }

    final additions = await db.query(
      'calendar_dates',
      where: 'exception_type = 1',
    );
    for (final row in additions) {
      final date = row['date'] as String?;
      final serviceId = row['service_id'] as String?;
      if (serviceId == null || date == null) continue;
      batch.insert(
        'service_days',
        {
          'service_id': serviceId,
          'service_date': date,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      if (++pending >= 500) {
        await batch.commit(noResult: true);
        batch = db.batch();
        pending = 0;
      }
    }

    final removals = await db.query(
      'calendar_dates',
      where: 'exception_type = 2',
    );
    for (final row in removals) {
      final date = row['date'] as String?;
      final serviceId = row['service_id'] as String?;
      if (serviceId == null || date == null) continue;
      await db.delete(
        'service_days',
        where: 'service_id = ? AND service_date = ?',
        whereArgs: [serviceId, date],
      );
    }

    if (pending > 0) {
      await batch.commit(noResult: true);
    }
  }

  Future<void> _buildStopRouteTypes(DatabaseExecutor db) async {
    await db.delete('stop_route_types');
    await db.execute('''
      INSERT INTO stop_route_types (stop_id, route_type)
      SELECT DISTINCT st.stop_id, r.type
      FROM stop_times st
      JOIN trips t ON t.trip_id = st.trip_id
      JOIN routes r ON r.route_id = t.route_id
      WHERE r.type IS NOT NULL
    ''');
  }

  bool _isServiceRunning(Map<String, Object?> cal, int weekday) {
    const columns = {
      DateTime.monday: 'monday',
      DateTime.tuesday: 'tuesday',
      DateTime.wednesday: 'wednesday',
      DateTime.thursday: 'thursday',
      DateTime.friday: 'friday',
      DateTime.saturday: 'saturday',
      DateTime.sunday: 'sunday',
    };
    final column = columns[weekday];
    if (column == null) return false;
    final value = cal[column];
    if (value is int) return value > 0;
    if (value is String) return (int.tryParse(value) ?? 0) > 0;
    return false;
  }

  DateTime? _parseDate(String? value) {
    if (value == null || value.length != 8) return null;
    final year = int.tryParse(value.substring(0, 4));
    final month = int.tryParse(value.substring(4, 6));
    final day = int.tryParse(value.substring(6, 8));
    if (year == null || month == null || day == null) return null;
    return DateTime.utc(year, month, day);
  }

  DateTime? _combineServiceDateAndTime(String? serviceDate, String? time) {
    if (serviceDate == null || time == null || time.isEmpty) return null;
    final base = _parseDate(serviceDate)?.toLocal();
    if (base == null) return null;
    final parts = time.split(':');
    if (parts.length < 2) return null;
    var hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    final second = parts.length > 2 ? int.tryParse(parts[2]) ?? 0 : 0;
    var date = DateTime(base.year, base.month, base.day);
    while (hour >= 24) {
      date = date.add(const Duration(days: 1));
      hour -= 24;
    }
    return DateTime(
      date.year,
      date.month,
      date.day,
      hour,
      minute,
      second,
    );
  }

  String _formatDateLocal(DateTime date) {
    final local = date.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y$m$d';
  }

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y$m$d';
  }

  List<String> _parseCsvLine(String line) {
    final result = <String>[];
    final buffer = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buffer.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        result.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }
    result.add(buffer.toString());
    return result;
  }

  Future<String?> _getMetadata(String key) async {
    final db = _db!;
    final rows = await db.query(
      'metadata',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> _setMetadata(
    String key,
    String value, {
    DatabaseExecutor? txn,
  }) async {
    final executor = txn ?? _db!;
    await executor.insert(
      'metadata',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<bool> _tryCopyBundledSeed(String dbPath) async {
    try {
      final data = await rootBundle.load('assets/gtfs/gtfs_seed.sqlite');
      final bytes =
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      final file = File(dbPath);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes, flush: true);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Database> _openDatabase(
    String path, {
    bool resetSchema = false,
  }) async {
    if (resetSchema && await File(path).exists()) {
      await File(path).delete();
    }
    return openDatabase(
      path,
      version: 1,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await _createSchema(db);
      },
    );
  }
}

class StaticGtfsDeparture {
  StaticGtfsDeparture({
    required this.tripId,
    required this.stopId,
    this.stopSequence,
    this.scheduledDeparture,
    this.serviceId,
    this.routeShortName,
    this.routeLongName,
    this.headsign,
    this.routeType,
  });

  final String tripId;
  final String stopId;
  final int? stopSequence;
  final DateTime? scheduledDeparture;
  final String? serviceId;
  final String? routeShortName;
  final String? routeLongName;
  final String? headsign;
  final int? routeType;
}
