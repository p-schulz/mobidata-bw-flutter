import 'package:flutter/material.dart';

import '../models/categories.dart';
import 'drawer_hint.dart';

class AppDrawer extends StatelessWidget {
  final bool showDrawerHint;
  final VoidCallback onCloseDrawerHint;
  final Map<DatasetCategory, String> categoryTitles;
  final DatasetCategory selectedCategory;
  final ValueChanged<DatasetCategory> onSelectCategory;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenImprint;

  const AppDrawer({
    super.key,
    required this.showDrawerHint,
    required this.onCloseDrawerHint,
    required this.categoryTitles,
    required this.selectedCategory,
    required this.onSelectCategory,
    required this.onOpenSettings,
    required this.onOpenImprint,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final Color drawerBg =
        isDark ? const Color.fromARGB(255, 25, 25, 25) : Colors.white;
    final Color drawerTextColor =
        isDark ? const Color.fromARGB(255, 88, 88, 88) : Colors.black;
    final Color drawerSubTextColor =
        drawerTextColor.withOpacity(isDark ? 0.9 : 0.75);

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: drawerBg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MobiData BW in Flutter',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: drawerTextColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '(Inoffiziell)',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: drawerSubTextColor,
                    ),
                  ),
                ],
              ),
            ),
            if (showDrawerHint)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: DrawerHint(onClose: onCloseDrawerHint),
              ),
            Expanded(
              child: ListView(
                children: [
                  for (final entry in categoryTitles.entries)
                    _DrawerCategoryTile(
                      category: entry.key,
                      label: entry.value,
                      selectedCategory: selectedCategory,
                      onTap: onSelectCategory,
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Einstellungen'),
              onTap: onOpenSettings,
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Impressum & Lizenzen'),
              onTap: onOpenImprint,
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerCategoryTile extends StatelessWidget {
  final DatasetCategory category;
  final String label;
  final DatasetCategory selectedCategory;
  final ValueChanged<DatasetCategory> onTap;

  const _DrawerCategoryTile({
    required this.category,
    required this.label,
    required this.selectedCategory,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = category == selectedCategory;
    final highlightColor =
        isSelected ? Theme.of(context).colorScheme.primary : null;

    IconData icon;
    switch (category) {
      case DatasetCategory.parking:
        icon = Icons.local_parking;
        break;
      case DatasetCategory.carsharing:
        icon = Icons.directions_car;
        break;
      case DatasetCategory.bikesharing:
        icon = Icons.pedal_bike;
        break;
      case DatasetCategory.scooters:
        icon = Icons.electric_scooter;
        break;
      case DatasetCategory.transit:
        icon = Icons.directions_bus;
        break;
      case DatasetCategory.charging:
        icon = Icons.ev_station;
        break;
      case DatasetCategory.construction:
        icon = Icons.construction;
        break;
      case DatasetCategory.bicycleNetwork:
        icon = Icons.directions_bike;
        break;
    }

    return ListTile(
      leading: Icon(
        icon,
        color: highlightColor ?? Theme.of(context).iconTheme.color,
      ),
      title: Text(
        label,
        style: TextStyle(
          color: highlightColor ?? Theme.of(context).colorScheme.onSurface,
        ),
      ),
      selected: isSelected,
      onTap: () => onTap(category),
    );
  }
}
