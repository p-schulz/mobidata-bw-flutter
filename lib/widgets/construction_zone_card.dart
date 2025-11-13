import 'package:flutter/material.dart';

import '../models/construction_site.dart';

class ConstructionZoneCard extends StatelessWidget {
  final ConstructionSite site;
  final VoidCallback onClose;

  const ConstructionZoneCard({
    super.key,
    required this.site,
    required this.onClose,
  });

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
            const Icon(Icons.warning, size: 28, color: Colors.redAccent),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    site.description ?? 'Baustelle',
                    style: theme.textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      if (site.street != null)
                        Text(
                          site.street!,
                          style: theme.textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (site.type != null)
                        Text(
                          site.type!,
                          style: theme.textTheme.bodySmall,
                        ),
                      if (site.direction != null)
                        Text(
                          'Richtung: ${site.direction}',
                          style: theme.textTheme.bodySmall,
                        ),
                      _buildTimeRange(site, theme),
                    ],
                  ),
                ],
              ),
            ),
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

  Widget _buildTimeRange(ConstructionSite site, ThemeData theme) {
    if (site.startTime == null && site.endTime == null) {
      return const SizedBox.shrink();
    }
    final start = site.startTime != null
        ? _fmt(site.startTime!)
        : 'unbekannt';
    final end =
        site.endTime != null ? _fmt(site.endTime!) : 'unbekannt';
    return Text('Zeitraum: $start - $end', style: theme.textTheme.bodySmall);
  }

  String _fmt(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
}
