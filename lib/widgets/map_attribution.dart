import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class MapAttributionWidget extends StatelessWidget {
  final bool isDarkMode;
  const MapAttributionWidget({super.key, required this.isDarkMode});

  static final Uri _mapTilerUri = Uri.parse('https://www.maptiler.com/');

  Future<void> _openMapTilerSite() async {
    if (!await launchUrl(_mapTilerUri, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not open MapTiler website');
    }
  }

  @override
  Widget build(BuildContext context) {
    final attributionText = '© MapTiler  © OpenStreetMap contributors';
    final backgroundColor = isDarkMode
        ? Colors.black.withOpacity(0.65)
        : Colors.white.withOpacity(0.85);
    final textColor = isDarkMode ? Colors.white : Colors.black87;

    return IgnorePointer(
      ignoring: false,
      child: Stack(
        children: [
          Positioned(
            left: 8,
            bottom: 48,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey[700] : Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: _openMapTilerSite,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Image.asset(
                      'assets/maptiler-logo.png',
                      height: 32,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 6,
            bottom: 8,
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
        ],
      ),
    );
  }
}
