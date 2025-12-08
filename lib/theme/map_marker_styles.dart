import 'package:flutter/material.dart';

class MapMarkerStyles {
  MapMarkerStyles._();

  static final Color selectionColor = Colors.orange.shade700;
  static const Color markerShadowColor = Color(0x33000000);
  static const Color markerStrongShadowColor = Color(0x55000000);
  static const Color clusterShadowColor = Color(0x44000000);

  static Color parkingStatusColor(String? status) {
    switch (status) {
      case 'free':
        return Colors.green.shade700;
      case 'full':
        return Colors.red.shade700;
      case 'closed':
        return Colors.grey.shade700;
      default:
        return Colors.blue.shade700;
    }
  }

  static Color parkingSpotStatusColor(String? status) {
    switch ((status ?? '').toUpperCase()) {
      case 'AVAILABLE':
        return Colors.green.shade700;
      case 'OCCUPIED':
      case 'UNAVAILABLE':
        return Colors.red.shade700;
      default:
        return Colors.blueGrey.shade700;
    }
  }

  static Color carsharingAvailabilityColor(int availableVehicles) =>
      availableVehicles > 0 ? Colors.green.shade600 : Colors.grey.shade600;

  static Color bikesharingAvailabilityColor(int availableVehicles) =>
      availableVehicles > 0 ? Colors.green.shade600 : Colors.red;

  static Color scooterStatusColor({
    required bool isDisabled,
    required double? batteryPercent,
  }) {
    if (isDisabled) return Colors.grey;
    if ((batteryPercent ?? 1) < 0.2) return Colors.orange;
    return Colors.lightGreen;
  }

  static Color carsharingMarkerColor({
    required int availableVehicles,
    required bool isSelected,
  }) =>
      isSelected
          ? selectionColor
          : carsharingAvailabilityColor(availableVehicles);

  static Color bikesharingMarkerColor({
    required int availableVehicles,
    required bool isSelected,
  }) =>
      isSelected
          ? selectionColor
          : bikesharingAvailabilityColor(availableVehicles);

  static Color scooterMarkerColor({
    required bool isDisabled,
    required double? batteryPercent,
    required bool isSelected,
  }) =>
      isSelected
          ? selectionColor
          : scooterStatusColor(
              isDisabled: isDisabled,
              batteryPercent: batteryPercent,
            );

  static Color parkingMarkerColor({
    required String? status,
    required bool isSelected,
  }) =>
      isSelected ? selectionColor : parkingStatusColor(status);

  static Color parkingSpotMarkerColor({
    required String? status,
    required bool isSelected,
  }) =>
      isSelected ? selectionColor : parkingSpotStatusColor(status);

  static Color transitMarkerColor({required bool isSelected}) =>
      isSelected ? selectionColor : Colors.indigoAccent;

  static final Color vehicleMarkerColor = Colors.orange.shade600;

  static Color constructionMarkerColor({required bool isSelected}) =>
      isSelected ? Colors.deepOrange : Colors.red;

  static Color chargingMarkerColor({required bool isSelected}) =>
      isSelected ? selectionColor : Colors.teal;

  static final Color parkingSiteClusterColor = Colors.blueGrey.shade700;
  static final Color parkingSpotClusterColor = Colors.orange.shade600;
  static final Color transitClusterColor = Colors.indigoAccent;
  static final Color carsharingClusterColor = Colors.green.shade700;
  static final Color bikesharingClusterColor = Colors.green.shade700;
  static final Color scooterClusterColor = Colors.lightGreen.shade700;
  static final Color constructionClusterColor = Colors.red.shade700;
  static final Color chargingClusterColor = Colors.teal.shade600;

  static const Color legendParkingFree = Colors.green;
  static const Color legendParkingFull = Colors.red;
  static const Color legendParkingUnknown = Colors.blue;
  static const Color legendParkingSpot = Colors.teal;
  static const Color legendCarsharingAvailable = Colors.green;
  static const Color legendCarsharingUnavailable = Colors.grey;
  static const Color legendBikesharingAvailable = Colors.green;
  static const Color legendBikesharingEmpty = Colors.red;
  static const Color legendScooterReady = Colors.lightGreen;
  static const Color legendScooterLowBattery = Colors.orange;
  static const Color legendTransit = Colors.indigo;
  static const Color legendCharging = Colors.teal;
}
