import 'package:flutter/material.dart';

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
              tooltip: 'Filter zurücksetzen',
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
