import 'package:flutter/material.dart';

enum AppThemeSetting {
  system,
  light,
  dark,
}

extension AppThemeSettingMode on AppThemeSetting {
  ThemeMode get themeMode {
    switch (this) {
      case AppThemeSetting.light:
        return ThemeMode.light;
      case AppThemeSetting.dark:
        return ThemeMode.dark;
      case AppThemeSetting.system:
      default:
        return ThemeMode.system;
    }
  }
}

class AppThemeSettings {
  static const Color primarySeedColor = Color(0xFF004C97);
  static const Color _bicycleDarkColor = Color(0xFFFF66FF);
  static const Color _bicycleLightColor = Color(0xFFFF1744);

  static ThemeData get lightTheme => _buildTheme(Brightness.light);

  static ThemeData get darkTheme => _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: primarySeedColor,
        brightness: brightness,
      ),
      useMaterial3: true,
    );
  }

  static bool isDarkTheme(ThemeData theme) =>
      theme.brightness == Brightness.dark;

  static Color searchFieldFillColor(ThemeData theme) =>
      theme.colorScheme.surfaceVariant
          .withOpacity(isDarkTheme(theme) ? 0.3 : 1);

  static Color bicyclePolylineColor(ThemeData theme) {
    final baseColor =
        isDarkTheme(theme) ? _bicycleDarkColor : _bicycleLightColor;
    final opacity = isDarkTheme(theme) ? 0.85 : 0.75;
    return baseColor.withOpacity(opacity);
  }

  static Color bicycleLegendColor(ThemeData theme) =>
      isDarkTheme(theme) ? _bicycleDarkColor : _bicycleLightColor;

  static Color legendBackgroundColor(ThemeData theme) => isDarkTheme(theme)
      ? Colors.black.withOpacity(0.6)
      : Colors.white.withOpacity(0.8);

  static Color legendTextColor(ThemeData theme) =>
      isDarkTheme(theme) ? Colors.white : Colors.black87;
}
