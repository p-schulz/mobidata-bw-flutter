import 'package:flutter/material.dart';

class DrawerHint extends StatelessWidget {
  final VoidCallback onClose;

  const DrawerHint({required this.onClose});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color: Colors.amber.shade50,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.swipe_right_alt,
              color: theme.colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Wähle hier die Datensatzkategorie.\n'
                'Aktuell ist „Parkplätze“ aktiv.',
                style: theme.textTheme.bodySmall,
              ),
            ),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(Icons.close, size: 18),
              onPressed: onClose,
              tooltip: 'Hinweis ausblenden',
            ),
          ],
        ),
      ),
    );
  }
}
