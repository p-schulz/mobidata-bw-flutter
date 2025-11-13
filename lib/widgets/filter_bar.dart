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
    this.transitShowBus = true,
    this.transitShowTram = true,
    this.transitShowSuburban = true,
    this.transitShowMetro = true,
    this.transitShowRail = true,
    this.onToggleTransitBus,
    this.onToggleTransitTram,
    this.onToggleTransitSuburban,
    this.onToggleTransitMetro,
    this.onToggleTransitRail,

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
  final bool transitShowBus;
  final bool transitShowTram;
  final bool transitShowSuburban;
  final bool transitShowMetro;
  final bool transitShowRail;
  final ValueChanged<bool>? onToggleTransitBus;
  final ValueChanged<bool>? onToggleTransitTram;
  final ValueChanged<bool>? onToggleTransitSuburban;
  final ValueChanged<bool>? onToggleTransitMetro;
  final ValueChanged<bool>? onToggleTransitRail;

  // --- Reset ---
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];

    if (category == DatasetCategory.parking) {
      chips.add(
        FilterChip(
          label: const Text('nur freie Parkplätze'),
          selected: showOnlyFreeParking,
          onSelected: onToggleOnlyFreeParking,
        ),
      );
    }

    if (category == DatasetCategory.carsharing) {
      chips.add(
        FilterChip(
          label: const Text('nur Stationen mit Fahrzeugen'),
          selected: showOnlyWithCars,
          onSelected: onToggleOnlyWithCars,
        ),
      );
    }

    if (category == DatasetCategory.bikesharing) {
      chips.add(
        FilterChip(
          label: const Text('nur Stationen mit Bikes'),
          selected: showOnlyBikeStationsWithBikes,
          onSelected: onToggleOnlyBikeStationsWithBikes,
        ),
      );
    }

    if (category == DatasetCategory.transit) {
      chips.add(
        FilterChip(
          label: const Text('Bahnhof + Haltestelle'),
          selected: showTransitStops,
          onSelected: onToggleTransitStops,
        ),
      );
      chips.addAll([
        FilterChip(
          label: const Text('Bus'),
          selected: transitShowBus,
          onSelected: onToggleTransitBus,
        ),
        FilterChip(
          label: const Text('Tram'),
          selected: transitShowTram,
          onSelected: onToggleTransitTram,
        ),
        FilterChip(
          label: const Text('S-Bahn'),
          selected: transitShowSuburban,
          onSelected: onToggleTransitSuburban,
        ),
        FilterChip(
          label: const Text('U-Bahn'),
          selected: transitShowMetro,
          onSelected: onToggleTransitMetro,
        ),
        FilterChip(
          label: const Text('Zug / Fernverkehr'),
          selected: transitShowRail,
          onSelected: onToggleTransitRail,
        ),
      ]);
    }

    return Card(
      elevation: 4,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: chips,
              ),
            ),
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
