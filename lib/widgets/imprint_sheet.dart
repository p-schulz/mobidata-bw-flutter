import 'package:flutter/material.dart';

class ImpressumSheet extends StatelessWidget {
  const ImpressumSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Impressum & Lizenzen',
                    style: theme.textTheme.titleLarge,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text('Hinweis', style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              const Text(
                'Diese App ist ein inoffizielles Projekt des Codevember e.V '
                'und steht in keinem offiziellen Zusammenhang mit MobiData BW oder der '
                'NVBW Nahverkehrsgesellschaft Baden-Württemberg mbH.',
              ),
              const SizedBox(height: 16),
              Text(
                'Rechtliches und Lizenzen',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              const Text(
                '• MobiData BW – zentrale Daten- und Serviceplattform für Mobilität in Baden-Württemberg.\n'
                '• Bereitstellung von Mobilitätsdaten teilweise unter '
                'der Datenlizenz Deutschland – Namensnennung 2.0 (DL-DE-BY 2.0). \n'
                '• Weitere Informationen: https://www.mobidata-bw.de/impressum/ \n'
                '• Verwendung von Open Data des Landesamt für Geoinformation und Landentwicklung Baden-Württemberg (LGL) '
                'für den Suchdienst von Adressen und Orte.\n '
                '• Datenquelle: LGL, www.lgl-bw.de, dl-de/by-2-0 \n'
                '• Weitere Informationen: https://www.lgl-bw.de/ \n'
                '• App-Entwicklung: Codevember e.V. (https://codevember.org), 2025',
              ),
              const SizedBox(height: 16),
              Text(
                'Open-Source-Komponenten',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              const Text(
                '• Flutter (Google)\n'
                '• flutter_map + OpenStreetMap-Tiles\n'
                '• Dio, Geolocator, flutter_spinkit\n'
                'Lizenzdetails siehe „Flutter Lizenzen anzeigen“.',
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () {
                    showLicensePage(
                      context: context,
                      applicationName: 'MobiData BW in Flutter',
                      applicationVersion: '0.1.0',
                    );
                  },
                  icon: const Icon(Icons.article_outlined),
                  label: const Text('Flutter-Lizenzen anzeigen'),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Schließen'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
