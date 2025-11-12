import '../models/categories.dart';
import 'package:flutter/material.dart';

class FilterBar extends StatelessWidget {
  final bool showOnlyAvailable;
  final ValueChanged<bool> onChangeAvailable;

  const FilterBar({
    super.key,
    required this.category,
    required this.showOnlyAvailable,
    required this.onChangeAvailable,

    // Parking
    this.showOnlyFreeParking = false,
    this.onToggleOnlyFreeParking,

    // Carsharing
    this.showOnlyWithCars = false,
    this.onToggleOnlyWithCars,

    // Bikesharing
    this.showOnlyBikeStationsWithBikes = false,
    this.onToggleOnlyBikeStationsWithBikes,

    // Transit
    this.showTransitStops = false,
    this.onToggleTransitStops,

    // Reset
    this.onReset,
  });

  final DatasetCategory category;

  // --- Parking ---
  final bool showOnlyFreeParking;
  final ValueChanged<bool>? onToggleOnlyFreeParking;

  // --- Carsharing ---
  final bool showOnlyWithCars;
  final ValueChanged<bool>? onToggleOnlyWithCars;

  // --- Bikesharing ---
  final bool showOnlyBikeStationsWithBikes;
  final ValueChanged<bool>? onToggleOnlyBikeStationsWithBikes;

  // --- Transit ---
  final bool showTransitStops;
  final ValueChanged<bool>? onToggleTransitStops;

  // --- Reset ---
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            // Kategorie-spezifische Chips
            if (category == DatasetCategory.parking)
              FilterChip(
                label: const Text('nur freie Parkplätze'),
                selected: showOnlyFreeParking,
                onSelected: onToggleOnlyFreeParking,
              ),

            if (category == DatasetCategory.carsharing)
              FilterChip(
                label: const Text('nur Stationen mit Fahrzeugen'),
                selected: showOnlyWithCars,
                onSelected: onToggleOnlyWithCars,
              ),

            if (category == DatasetCategory.bikesharing)
              FilterChip(
                label: const Text('nur Stationen mit Bikes'),
                selected: showOnlyBikeStationsWithBikes,
                onSelected: onToggleOnlyBikeStationsWithBikes,
              ),

            if (category == DatasetCategory.transit)
              FilterChip(
                label: const Text('Bahnhof + Haltestelle'),
                selected: showTransitStops,
                onSelected: onToggleTransitStops,
              ),

            const Spacer(),

            // Reset-Button (Verhalten bleibt wie bisher)
            IconButton(
              tooltip: 'Zurücksetzen',
              icon: const Icon(Icons.restart_alt),
              onPressed: onReset,
            ),
          ],
        ),
      ),
    );
  }
}
