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

/*import 'package:flutter/material.dart';

class FilterBar extends StatelessWidget {
  final bool showOnlyAvailable;
  final ValueChanged<bool> onChangeAvailable;

  const FilterBar({
    super.key,
    required this.showOnlyAvailable,
    required this.onChangeAvailable,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      color: Colors.white.withOpacity(0.9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                FilterChip(
                  label: const Text('Freie Parkplätze'),
                  selected: showOnlyAvailable,
                  onSelected: onChangeAvailable,
                  selectedColor: Colors.green.shade200,
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Aktualisieren',
              onPressed: () {
                onChangeAvailable(false);
              },
            ),
          ],
        ),
      ),
    );
  }
}
*/
