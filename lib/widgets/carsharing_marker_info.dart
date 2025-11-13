import 'package:flutter/material.dart';
import '../models/carsharing_offer.dart';

class CarsharingInfo extends StatelessWidget {
  final CarsharingOffer offer;
  final VoidCallback onClose;

  const CarsharingInfo({required this.offer, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.directions_car, size: 28),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    offer.name,
                    style: theme.textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      if (offer.availableVehicles != null)
                        Text(
                          'Kapazität: ${offer.availableVehicles}',
                          style: theme.textTheme.bodySmall,
                        ),
                      if (offer.isRentingAllowed != null)
                        Text(
                          'Status: ${offer.isRentingAllowed}',
                          style: theme.textTheme.bodySmall,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  builder: (_) => _CarsharingSheet(offer: offer),
                );
              },
              child: const Text('Details'),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close),
              tooltip: 'Schließen',
            ),
          ],
        ),
      ),
    );
  }
}

class _CarsharingSheet extends StatelessWidget {
  final CarsharingOffer offer;
  const _CarsharingSheet({required this.offer});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(offer.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (offer.availableVehicles != null)
              Text('Kapazität: ${offer.availableVehicles}'),
            if (offer.isRentingAllowed != null)
              Text('Status: ${offer.isRentingAllowed}'),
            if (offer.name.isNotEmpty) Text('Adresse: ${offer.name}'),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.close),
                  label: const Text('Schließen'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
