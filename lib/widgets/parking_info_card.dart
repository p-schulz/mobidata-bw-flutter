import 'package:flutter/material.dart';
import '../models/parking_site.dart';

class ParkingInfoCard extends StatelessWidget {
  final ParkingSite site;
  final VoidCallback onClose;

  const ParkingInfoCard({required this.site, required this.onClose});

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
            const Icon(Icons.local_parking, size: 28),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    site.name,
                    style: theme.textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      if (site.availableSpaces != null)
                        Text(
                          'Kapazität: ${site.availableSpaces}',
                          style: theme.textTheme.bodySmall,
                        ),
                      if (site.status != null)
                        Text(
                          'Status: ${site.status}',
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
                  builder: (_) => _ParkingSheet(site: site),
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

class _ParkingSheet extends StatelessWidget {
  final ParkingSite site;
  const _ParkingSheet({required this.site});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(site.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (site.availableSpaces != null)
              Text('Kapazität: ${site.availableSpaces}'),
            if (site.status != null) Text('Status: ${site.status}'),
            if (site.roadName != null) Text('Adresse: ${site.roadName}'),
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
