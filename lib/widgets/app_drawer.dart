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
    final colors = _DrawerThemeColors.fromTheme(theme);

    return Drawer(
      backgroundColor: colors.background,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: colors.headerBackground),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mobility4BW',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: colors.primaryText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Mobility App for BW powered by',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Image.asset(
                    'assets/mobidata-logo.png',
                    height: 48,
                    fit: BoxFit.contain,
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
                      colors: colors,
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: Text(
                'Einstellungen',
                style: TextStyle(color: colors.menuTileText),
              ),
              iconColor: colors.menuTileText,
              textColor: colors.menuTileText,
              tileColor: colors.menuTileBackground,
              onTap: onOpenSettings,
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(
                'Impressum & Lizenzen',
                style: TextStyle(color: colors.menuTileText),
              ),
              iconColor: colors.menuTileText,
              textColor: colors.menuTileText,
              tileColor: colors.menuTileBackground,
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
  final _DrawerThemeColors colors;

  const _DrawerCategoryTile({
    required this.category,
    required this.label,
    required this.selectedCategory,
    required this.onTap,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = category == selectedCategory;
    final textColor =
        isSelected ? colors.tileSelectedText : colors.tileUnselectedText;
    final backgroundColor =
        isSelected ? colors.tileSelectedBackground : Colors.transparent;
    final iconColor = isSelected
        ? colors.tileSelectedIconColor
        : colors.tileUnselectedIconColor;

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

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: iconColor,
        ),
        title: Text(
          label,
          style: TextStyle(color: textColor),
        ),
        selected: isSelected,
        selectedTileColor: colors.tileSelectedBackground,
        onTap: () => onTap(category),
      ),
    );
  }
}

class _DrawerThemeColors {
  final Color background;
  final Color headerBackground;
  final Color primaryText;
  final Color secondaryText;
  final Color tileSelectedBackground;
  final Color tileSelectedText;
  final Color tileUnselectedText;
  final Color tileSelectedIconColor;
  final Color tileUnselectedIconColor;
  final Color menuTileBackground;
  final Color menuTileText;

  const _DrawerThemeColors({
    required this.background,
    required this.headerBackground,
    required this.primaryText,
    required this.secondaryText,
    required this.tileSelectedBackground,
    required this.tileSelectedText,
    required this.tileUnselectedText,
    required this.tileSelectedIconColor,
    required this.tileUnselectedIconColor,
    required this.menuTileBackground,
    required this.menuTileText,
  });

  factory _DrawerThemeColors.fromTheme(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
    final onPrimary = theme.colorScheme.onPrimary;
    if (isDark) {
      return _DrawerThemeColors(
        background: const Color(0xFF111111),
        headerBackground: const Color(0xFF1C1C1C),
        primaryText: Colors.white,
        secondaryText: Colors.white70,
        tileSelectedBackground: Color(0xFF006EAF),
        tileSelectedText: Colors.white,
        tileUnselectedText: Colors.grey[300]!,
        tileSelectedIconColor: Color(0xFFFFCC00),
        tileUnselectedIconColor: Colors.white70,
        menuTileBackground: Colors.black,
        menuTileText: Colors.white,
      );
    }

    return _DrawerThemeColors(
      background: Colors.white,
      headerBackground: const Color(0xFFF4F6FB),
      primaryText: const Color(0xFF0E233C),
      secondaryText: const Color(0xFF4A5D74),
      tileSelectedBackground: Color(0xFF006EAF),
      tileSelectedText: Colors.white,
      tileUnselectedText: const Color(0xFF232323),
      tileSelectedIconColor: Color(0xFFFFCC00),
      tileUnselectedIconColor: const Color(0xFF616161),
      menuTileBackground: const Color(0xFFF1F3F7),
      menuTileText: const Color(0xFF1B1F2B),
    );
  }

  /*
  factory _DrawerThemeColors.fromTheme(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
    final onPrimary = theme.colorScheme.onPrimary;
    if (isDark) {
      return _DrawerThemeColors(
        background: const Color(0xFF111111),
        headerBackground: const Color(0xFF1C1C1C),
        primaryText: Colors.white,
        secondaryText: Colors.white70,
        tileSelectedBackground: primary.withOpacity(0.25),
        tileSelectedText: onPrimary,
        tileUnselectedText: Colors.white.withOpacity(0.9),
        tileSelectedIconColor: onPrimary,
        tileUnselectedIconColor: Colors.white70,
        menuTileBackground: Colors.white.withOpacity(0.05),
        menuTileText: Colors.white,
      );
    }

    return _DrawerThemeColors(
      background: Colors.white,
      headerBackground: const Color(0xFFF4F6FB),
      primaryText: const Color(0xFF0E233C),
      secondaryText: const Color(0xFF4A5D74),
      tileSelectedBackground: primary.withOpacity(0.12),
      tileSelectedText: primary,
      tileUnselectedText: const Color(0xFF232323),
      tileSelectedIconColor: primary,
      tileUnselectedIconColor: const Color(0xFF616161),
      menuTileBackground: const Color(0xFFF1F3F7),
      menuTileText: const Color(0xFF1B1F2B),
    );
  }*/
}
