import 'package:flutter/material.dart';

import '../models/charging_station.dart';

class ChargingInfoCard extends StatelessWidget {
  final ChargingStation station;
  final VoidCallback onClose;

  const ChargingInfoCard({
    super.key,
    required this.station,
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
            const Icon(Icons.ev_station, size: 28),
            const SizedBox(width: 8),
            Expanded(
              child: _ChargingDetails(station: station),
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
}

class _ChargingDetails extends StatelessWidget {
  final ChargingStation station;

  const _ChargingDetails({required this.station});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          station.name,
          style: theme.textTheme.titleMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            if (station.status != null)
              Text('Status: ${station.status}',
                  style: theme.textTheme.bodySmall),
            if (station.address != null)
              Text(station.address!,
                  style: theme.textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis),
            if (station.operatorName != null)
              Text('Betreiber: ${station.operatorName}',
                  style: theme.textTheme.bodySmall),
            Text(
              'Anschlüsse: ${station.connectorCount}'
              '${station.maxPowerKw != null ? ' bis ${station.maxPowerKw} kW' : ''}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ],
    );
  }
}
