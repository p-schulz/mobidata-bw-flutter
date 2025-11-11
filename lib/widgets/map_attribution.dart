import 'package:flutter/material.dart';
import '../models/app_theme_setting.dart';

class MapAttributionWidget extends StatelessWidget {
  final bool isDarkMode;
  const MapAttributionWidget({super.key, required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    final attributionText = isDarkMode
        ? 'Map tiles by CartoDB (CARTO), Lizenz CC-BY 3.0,\nDaten © OpenStreetMap-Mitwirkende (ODbL)'
        : '© OpenStreetMap-Mitwirkende, ODbL';

    return Align(
      alignment: Alignment.bottomRight,
      child: Container(
        margin: const EdgeInsets.all(6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          attributionText,
          textAlign: TextAlign.right,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9.5,
            height: 1.2,
          ),
        ),
      ),
    );
  }
}
