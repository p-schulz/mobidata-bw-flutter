import 'package:latlong2/latlong.dart';

class BicycleSegment {
  final List<LatLng> points;
  final double strokeWidth;

  BicycleSegment({
    required this.points,
    this.strokeWidth = 3,
  });

  BicycleSegment copyWith({
    List<LatLng>? points,
    double? strokeWidth,
  }) =>
      BicycleSegment(
        points: points ?? this.points,
        strokeWidth: strokeWidth ?? this.strokeWidth,
      );
}
