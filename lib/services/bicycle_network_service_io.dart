import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:proj4dart/proj4dart.dart' as proj4;
import 'package:simplify/simplify.dart' as poly_simplify;
import 'package:sqlite3/sqlite3.dart' as sqlite3;

import '../models/bicycle_segment.dart';

class BicycleNetworkService {
  static const _endpoint =
      'https://api.mobidata-bw.de/datasets/radvis/radnetz_bw.gpkg';
  static const _fileName = 'radnetz_bw.gpkg';
  static const _cacheDuration = Duration(days: 30);

  final Dio _client;
  bool _loggedDatasetInfo = false;
  LatLng Function(double x, double y)? _coordinateConverter;
  _ProjectedBounds Function(LatLngBounds bounds)? _boundsProjector;
  proj4.Projection? _datasetProjection;
  final proj4.Projection _wgs84 = _loadWgs84();

  BicycleNetworkService({Dio? client}) : _client = client ?? Dio();

  static proj4.Projection _loadWgs84() {
    final existing = proj4.Projection.get('EPSG:4326');
    if (existing != null) return existing;
    proj4.Projection.add(
      'EPSG:4326',
      '+proj=longlat +datum=WGS84 +no_defs +type=crs',
    );
    return proj4.Projection.get('EPSG:4326')!;
  }

  Future<List<BicycleSegment>> fetchSegments({
    required LatLngBounds bounds,
  }) async {
    if (kIsWeb) {
      throw UnsupportedError(
        'Das Radnetz ist derzeit nur auf nativen Plattformen verfügbar.',
      );
    }

    final file = await _ensureLocalFile();
    final database = sqlite3.sqlite3.open(file.path);
    try {
      final tableName = _lookupFeatureTable(database);
      final geometryColumn = _lookupGeometryColumn(database, tableName);
      final converter = _resolveCoordinateConverter(database, tableName);
      final projectedBounds = _projectBounds(bounds);
      _logDatasetInfo(database, tableName);
      final rtreeName = 'rtree_${tableName}_$geometryColumn';
      final hasRtree = _hasTable(database, rtreeName);

      final reader = _GpkgGeometryReader(converter);
      final segments = <BicycleSegment>[];
      int rowsExamined = 0;

      void runQuery({required bool useSpatialFilter}) {
        final queryBuffer = StringBuffer();
        queryBuffer.write(
          'SELECT rowid AS id, "$geometryColumn" AS geom FROM "$tableName" ',
        );
        final params = <Object?>[];

        if (useSpatialFilter && projectedBounds != null) {
          queryBuffer.write(
            'WHERE rowid IN (SELECT id FROM "$rtreeName" '
            'WHERE maxx >= ? AND minx <= ? AND maxy >= ? AND miny <= ?) ',
          );
          params.addAll([
            projectedBounds.minX,
            projectedBounds.maxX,
            projectedBounds.minY,
            projectedBounds.maxY,
          ]);
        }
        queryBuffer.write('LIMIT 5000');

        final stmt = database.prepare(queryBuffer.toString());
        try {
          final rows = stmt.select(params);
          rowsExamined += rows.length;
          for (final row in rows) {
            final blob = row['geom'];
            if (blob is! Uint8List) continue;
            final parts = reader.read(blob);
            for (final line in parts) {
              if (line.length < 2) continue;
              if (!_segmentIntersectsBounds(line, bounds)) continue;
              segments.add(BicycleSegment(points: line));
            }
          }
        } finally {
          stmt.dispose();
        }
      }

      final useSpatialFilter = hasRtree && projectedBounds != null;
      runQuery(useSpatialFilter: useSpatialFilter);
      if (segments.isEmpty && useSpatialFilter) {
        print(
          '[BicycleNetwork] Spatial filter returned 0 rows, fetching without filter.',
        );
        runQuery(useSpatialFilter: false);
      }
      final simplified = _simplifySegments(segments, bounds);
      print(
        '[BicycleNetwork] Query scanned $rowsExamined rows. '
        'Loaded ${simplified.length} segments for bounds '
        '${bounds.south},${bounds.west} - ${bounds.north},${bounds.east}',
      );
      return simplified;
    } finally {
      database.dispose();
    }
  }

  void _logDatasetInfo(sqlite3.Database db, String tableName) {
    if (_loggedDatasetInfo) return;
    try {
      final result = db.select('SELECT COUNT(*) as cnt FROM "$tableName"');
      final count = result.isNotEmpty ? result.first['cnt'] as int : 0;
      print('[BicycleNetwork] Dataset "$tableName" contains $count features.');
    } catch (e) {
      print('[BicycleNetwork] Failed to count features: $e');
    }
    _loggedDatasetInfo = true;
  }

  LatLng Function(double x, double y) _resolveCoordinateConverter(
    sqlite3.Database db,
    String tableName,
  ) {
    if (_coordinateConverter != null) return _coordinateConverter!;

    final result = db.select(
      'SELECT gc.srs_id, sr.organization, sr.organization_coordsys_id '
      'FROM gpkg_geometry_columns gc '
      'JOIN gpkg_spatial_ref_sys sr ON gc.srs_id = sr.srs_id '
      'WHERE gc.table_name = ? LIMIT 1',
      [tableName],
    );

    String? organization;
    int? epsgId;
    if (result.isNotEmpty) {
      organization = (result.first['organization'] as String?)?.toUpperCase();
      epsgId = result.first['organization_coordsys_id'] as int?;
    }
    print(
      '[BicycleNetwork] Using projection '
      '${organization ?? 'unknown'}:${epsgId ?? '?'}',
    );

    if (organization == 'EPSG' && (epsgId == 4326 || epsgId == 4258)) {
      _coordinateConverter = (x, y) => LatLng(y, x);
      _boundsProjector = (bounds) => _ProjectedBounds(
            minX: bounds.west,
            maxX: bounds.east,
            minY: bounds.south,
            maxY: bounds.north,
          );
      return _coordinateConverter!;
    }

    if (organization == 'EPSG' && epsgId == 25832) {
      const projName = 'RADNETZ_EPSG25832';
      if (proj4.Projection.get(projName) == null) {
        proj4.Projection.add(
          projName,
          '+proj=utm +zone=32 +ellps=GRS80 +units=m +no_defs +type=crs',
        );
      }
      _datasetProjection = proj4.Projection.get(projName)!;
      _coordinateConverter = (x, y) {
        final result = _datasetProjection!.transform(
          _wgs84,
          proj4.Point(x: x, y: y),
        );
        return LatLng(result.y.toDouble(), result.x.toDouble());
      };
      _boundsProjector = (bounds) {
        final sw = proj4.Point(x: bounds.west, y: bounds.south);
        final ne = proj4.Point(x: bounds.east, y: bounds.north);
        final swProj = _wgs84.transform(_datasetProjection!, sw);
        final neProj = _wgs84.transform(_datasetProjection!, ne);
        return _ProjectedBounds(
          minX: math.min(swProj.x, neProj.x),
          maxX: math.max(swProj.x, neProj.x),
          minY: math.min(swProj.y, neProj.y),
          maxY: math.max(swProj.y, neProj.y),
        );
      };
      return _coordinateConverter!;
    }

    _coordinateConverter = (x, y) => LatLng(y, x);
    _boundsProjector = (bounds) => _ProjectedBounds(
          minX: bounds.west,
          maxX: bounds.east,
          minY: bounds.south,
          maxY: bounds.north,
        );
    return _coordinateConverter!;
  }

  _ProjectedBounds? _projectBounds(LatLngBounds bounds) {
    final projector = _boundsProjector;
    if (projector == null) return null;
    return projector(bounds);
  }

  Future<File> _ensureLocalFile() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, _fileName));
    if (await file.exists()) {
      final modified = await file.lastModified();
      if (DateTime.now().difference(modified) < _cacheDuration) {
        print('[BicycleNetwork] Using cached GeoPackage at ${file.path}');
        return file;
      }
    } else {
      await file.parent.create(recursive: true);
    }

    final tempFile = File('${file.path}.download');
    if (await tempFile.exists()) {
      await tempFile.delete();
    }

    print('[BicycleNetwork] Downloading GeoPackage…');
    final stopwatch = Stopwatch()..start();
    await _client.download(
      _endpoint,
      tempFile.path,
      options: Options(responseType: ResponseType.bytes),
    );
    stopwatch.stop();
    int size = 0;
    try {
      size = await tempFile.length();
    } on PathNotFoundException {
      // File might be moved/renamed already; ignore to prevent noisy error.
    }
    print(
      '[BicycleNetwork] Download finished in '
      '${stopwatch.elapsed.inSeconds}s, size ${size > 0 ? size : 'unknown'} bytes',
    );
    await tempFile.rename(file.path);
    return file;
  }

  String _lookupFeatureTable(sqlite3.Database db) {
    final result = db.select(
      "SELECT table_name FROM gpkg_contents WHERE data_type = 'features'",
    );
    if (result.isEmpty) {
      throw StateError('Keine Feature-Tabelle in GeoPackage gefunden');
    }
    const preferred = [
      'Streckenabschnitt',
      'Route',
    ];
    for (final name in preferred) {
      for (final row in result) {
        if ((row['table_name'] as String).toLowerCase() == name.toLowerCase()) {
          return row['table_name'] as String;
        }
      }
    }
    return result.first['table_name'] as String;
  }

  String _lookupGeometryColumn(sqlite3.Database db, String tableName) {
    final result = db.select(
      'SELECT column_name FROM gpkg_geometry_columns '
      'WHERE table_name = ? LIMIT 1',
      [tableName],
    );
    if (result.isEmpty) {
      throw StateError(
        'Kein Geometriespalte für Tabelle $tableName gefunden.',
      );
    }
    return result.first['column_name'] as String;
  }

  bool _hasTable(sqlite3.Database db, String name) {
    final result = db.select(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      [name],
    );
    return result.isNotEmpty;
  }
}

class _GpkgGeometryReader {
  _GpkgGeometryReader(this._convert);

  final LatLng Function(double x, double y) _convert;

  List<List<LatLng>> read(Uint8List data) {
    final buffer = ByteData.sublistView(data);
    var offset = 0;

    if (buffer.getUint16(offset, Endian.big) != 0x4750) {
      return const [];
    }
    offset += 2; // magic
    offset += 1; // version
    final flags = buffer.getUint8(offset);
    offset += 1;
    offset += 4; // srs id

    final envelopeIndicator = (flags >> 1) & 0x07;
    offset += _envelopeSize(envelopeIndicator);

    final reader = _WkbReader(buffer, offset, _convert);
    return reader.readGeometry();
  }

  int _envelopeSize(int indicator) {
    switch (indicator) {
      case 0:
        return 0;
      case 1:
        return 4 * 8;
      case 2:
      case 3:
        return 6 * 8;
      case 4:
        return 8 * 8;
      default:
        return 0;
    }
  }
}

class _WkbReader {
  _WkbReader(this.data, this.offset, this._convert);

  final ByteData data;
  int offset;
  final LatLng Function(double x, double y) _convert;

  List<List<LatLng>> readGeometry() {
    final endian = _readEndian();
    final typeWithDims = data.getUint32(offset, endian);
    offset += 4;
    return _readGeometryOfType(endian, typeWithDims);
  }

  List<List<LatLng>> _readGeometryOfType(Endian endian, int typeWithDims) {
    final dims = typeWithDims ~/ 1000;
    final baseType = typeWithDims % 1000;
    switch (baseType) {
      case 2:
        final line = _readLineString(endian, dims);
        return line.isEmpty ? const [] : [line];
      case 5:
        return _readMultiLineString(endian);
      case 7:
        return _readGeometryCollection(endian);
      default:
        print('[BicycleNetwork] Unsupported WKB geometry type $baseType');
        return const [];
    }
  }

  Endian _readEndian() {
    final order = data.getUint8(offset);
    offset += 1;
    return order == 1 ? Endian.little : Endian.big;
  }

  List<LatLng> _readLineString(Endian endian, int dims) {
    final hasZ = dims == 1 || dims == 3;
    final hasM = dims == 2 || dims == 3;
    final count = data.getUint32(offset, endian);
    offset += 4;

    final points = <LatLng>[];
    for (var i = 0; i < count; i++) {
      final x = data.getFloat64(offset, endian);
      offset += 8;
      final y = data.getFloat64(offset, endian);
      offset += 8;
      if (hasZ) {
        offset += 8;
      }
      if (hasM) {
        offset += 8;
      }
      points.add(_convert(x, y));
    }
    return points;
  }

  List<List<LatLng>> _readMultiLineString(Endian endian) {
    final count = data.getUint32(offset, endian);
    offset += 4;
    final lines = <List<LatLng>>[];
    for (var i = 0; i < count; i++) {
      final nestedEndian = _readEndian();
      final type = data.getUint32(offset, nestedEndian);
      offset += 4;
      lines.addAll(_readGeometryOfType(nestedEndian, type));
    }
    return lines;
  }

  List<List<LatLng>> _readGeometryCollection(Endian endian) {
    final count = data.getUint32(offset, endian);
    offset += 4;
    final geometries = <List<LatLng>>[];
    for (var i = 0; i < count; i++) {
      geometries.addAll(readGeometry());
    }
    return geometries;
  }
}

class _ProjectedBounds {
  final double minX;
  final double maxX;
  final double minY;
  final double maxY;

  _ProjectedBounds({
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
  });
}

bool _segmentIntersectsBounds(List<LatLng> points, LatLngBounds bounds) {
  for (final point in points) {
    if (point.latitude >= bounds.south &&
        point.latitude <= bounds.north &&
        point.longitude >= bounds.west &&
        point.longitude <= bounds.east) {
      return true;
    }
  }
  return false;
}

List<BicycleSegment> _simplifySegments(
  List<BicycleSegment> segments,
  LatLngBounds bounds,
) {
  final tolerance = _simplificationTolerance(bounds);
  final targetStrokeWidth = _strokeWidthForBounds(bounds);
  final simplified = <BicycleSegment>[];
  for (final segment in segments) {
    if (segment.points.length < 2) continue;
    List<LatLng> points = segment.points;
    if (tolerance > 0) {
      final converted = points
          .map(
            (p) => math.Point<double>(p.longitude, p.latitude),
          )
          .toList(growable: false);
      final reduced = poly_simplify.simplify<math.Point<double>>(
        converted,
        tolerance: tolerance,
        highestQuality: false,
      );
      if (reduced.length >= 2) {
        points = reduced
            .map((pt) => LatLng(pt.y.toDouble(), pt.x.toDouble()))
            .toList(growable: false);
      }
    }
    if (points.length < 2) continue;
    simplified.add(
      segment.copyWith(
        points: points,
        strokeWidth: targetStrokeWidth,
      ),
    );
  }
  return _limitSegmentsForBounds(simplified, bounds);
}

List<BicycleSegment> _limitSegmentsForBounds(
  List<BicycleSegment> segments,
  LatLngBounds bounds,
) {
  final maxSegments = _maxSegmentsForBounds(bounds);
  if (segments.length <= maxSegments) return segments;
  final step = (segments.length / maxSegments).ceil();
  final limited = <BicycleSegment>[];
  for (var i = 0; i < segments.length; i += step) {
    limited.add(segments[i]);
  }
  return limited;
}

int _maxSegmentsForBounds(LatLngBounds bounds) {
  final span = _boundsSpan(bounds);
  if (span > 8) return 200;
  if (span > 4) return 350;
  if (span > 2) return 600;
  if (span > 1) return 900;
  return 1200;
}

double _simplificationTolerance(LatLngBounds bounds) {
  final span = _boundsSpan(bounds);
  if (span > 8) return 0.04;
  if (span > 4) return 0.02;
  if (span > 2) return 0.01;
  if (span > 1) return 0.006;
  if (span > 0.5) return 0.003;
  return 0.0015;
}

double _strokeWidthForBounds(LatLngBounds bounds) {
  final span = _boundsSpan(bounds);
  if (span > 8) return 1.2;
  if (span > 4) return 1.6;
  if (span > 2) return 2.0;
  if (span > 1) return 2.5;
  return 3.0;
}

double _boundsSpan(LatLngBounds bounds) {
  final lat = (bounds.north - bounds.south).abs();
  final lon = (bounds.east - bounds.west).abs();
  return math.max(lat, lon);
}
