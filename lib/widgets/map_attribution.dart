import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class MapAttributionWidget extends StatelessWidget {
  final bool isDarkMode;
  const MapAttributionWidget({super.key, required this.isDarkMode});

  static final Uri _osmCopyrightUri =
      Uri.parse('https://www.openstreetmap.org/copyright');

  Future<void> _openOsmCopyright() async {
    if (!await launchUrl(_osmCopyrightUri,
        mode: LaunchMode.externalApplication)) {
      debugPrint('Could not open OpenStreetMap copyright page');
    }
  }

  @override
  Widget build(BuildContext context) {
    const attributionText = '© OpenStreetMap contributors  ·  Protomaps';
    final backgroundColor = isDarkMode
        ? Colors.black.withOpacity(0.65)
        : Colors.white.withOpacity(0.85);
    final textColor = isDarkMode ? Colors.white : Colors.black87;

    return Stack(
      children: [
        Positioned(
          right: 6,
          bottom: 8,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: _openOsmCopyright,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  attributionText,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 10,
                    height: 1.2,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
