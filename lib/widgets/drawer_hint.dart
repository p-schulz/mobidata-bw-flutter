import 'package:flutter/material.dart';

class DrawerHint extends StatelessWidget {
  final VoidCallback onClose;

  const DrawerHint({required this.onClose});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bool isDark = colorScheme.brightness == Brightness.dark;
    final Color backgroundColor =
        isDark ? colorScheme.surfaceVariant.withOpacity(0.7) : colorScheme.secondaryContainer;
    final Color foregroundColor =
        isDark ? colorScheme.onSurfaceVariant : colorScheme.onSecondaryContainer;

    return Card(
      color: backgroundColor,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.swipe_right_alt,
              color: colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Wähle hier die Datensatzkategorie.\n'
                'Aktuell ist „Parkplätze“ aktiv.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: foregroundColor,
                ),
              ),
            ),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: Icon(
                Icons.close,
                size: 18,
                color: foregroundColor,
              ),
              onPressed: onClose,
              tooltip: 'Hinweis ausblenden',
            ),
          ],
        ),
      ),
    );
  }
}
