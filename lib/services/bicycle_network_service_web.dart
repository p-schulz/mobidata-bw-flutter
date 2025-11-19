import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';

import '../models/bicycle_segment.dart';

class BicycleNetworkService {
  BicycleNetworkService({Object? client});

  Future<List<BicycleSegment>> fetchSegments({
    required LatLngBounds bounds,
  }) async {
    throw UnsupportedError(
      'Das Radnetz ist im Web-Build nicht verfügbar.',
    );
  }
}
