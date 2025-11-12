import 'package:flutter/material.dart';

import '../models/transit_departure.dart';
import '../models/transit_stop.dart';

class TransitDepartureBoard extends StatelessWidget {
  final TransitStop stop;
  final List<TransitDeparture> departures;
  final bool loading;
  final String? error;
  final VoidCallback onClose;
  final VoidCallback? onRefresh;

  const TransitDepartureBoard({
    super.key,
    required this.stop,
    required this.departures,
    required this.loading,
    required this.error,
    required this.onClose,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.train, size: 28),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stop.name,
                        style: theme.textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (stop.description != null)
                        Text(
                          stop.description!,
                          style: theme.textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                if (onRefresh != null)
                  IconButton(
                    tooltip: 'Aktualisieren',
                    icon: const Icon(Icons.refresh),
                    onPressed: onRefresh,
                  ),
                IconButton(
                  tooltip: 'Schließen',
                  icon: const Icon(Icons.close),
                  onPressed: onClose,
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),
            if (loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        error!,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: Colors.red.shade700),
                      ),
                    ),
                  ],
                ),
              )
            else if (departures.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Keine Abfahrten gefunden'),
              )
            else
              _DepartureTable(departures: departures),
          ],
        ),
      ),
    );
  }
}

class _DepartureTable extends StatelessWidget {
  final List<TransitDeparture> departures;

  const _DepartureTable({required this.departures});

  @override
  Widget build(BuildContext context) {
    final headerStyle =
        Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 11);
    return Column(
      children: [
        Row(
          children: [
            _cell('Zeit', flex: 2, style: headerStyle, isHeader: true),
            _cell('Versp.', flex: 1, style: headerStyle, isHeader: true),
            _cell('Linie', flex: 2, style: headerStyle, isHeader: true),
            _cell('Richtung', flex: 4, style: headerStyle, isHeader: true),
            _cell('Gleis', flex: 2, style: headerStyle, isHeader: true),
          ],
        ),
        const Divider(height: 8),
        SizedBox(
          height: 220,
          child: ListView.separated(
            itemCount: departures.length,
            itemBuilder: (context, index) {
              final dep = departures[index];
              return Row(
                children: [
                  _cell(_formatTime(dep), flex: 2),
                  _cell(
                    _formatDelay(dep),
                    flex: 1,
                    style: TextStyle(
                      color: _delayColor(dep.delayMinutes),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  _cell(dep.routeShortName, flex: 2),
                  _cell(dep.headsign ?? '-', flex: 4),
                  _cell(dep.platform ?? '-', flex: 2),
                ],
              );
            },
            separatorBuilder: (_, __) => const Divider(height: 6),
          ),
        ),
      ],
    );
  }

  static Widget _cell(
    String text, {
    required int flex,
    TextStyle? style,
    bool isHeader = false,
  }) {
    final effectiveStyle =
        style ?? const TextStyle(fontSize: 12, fontWeight: FontWeight.w500);
    return Expanded(
      flex: flex,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: isHeader
            ? effectiveStyle.copyWith(fontWeight: FontWeight.bold)
            : effectiveStyle,
      ),
    );
  }

  static String _formatTime(TransitDeparture dep) {
    final dt = dep.realtimeDeparture ?? dep.scheduledDeparture;
    if (dt != null) {
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }
    return '--';
  }

  static String _formatDelay(TransitDeparture dep) {
    final delay = dep.delayMinutes;
    if (delay == null || delay == 0) return '';
    final sign = delay > 0 ? '+' : '';
    return '$sign$delay';
  }

  static Color? _delayColor(int? delay) {
    if (delay == null || delay == 0) return Colors.green;
    if (delay > 0) return Colors.red.shade600;
    return Colors.blue.shade600;
  }
}
