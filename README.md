# MobiData BW Flutter Starter (Android-first)

Ein minimales Flutter-Projekt.

Funktionen: Karte (OSM) + MobiData BW ParkAPI – lädt Parkplätze innerhalb der aktuellen Kartenregion.

## Voraussetzungen
- Flutter SDK (`flutter doctor` pass)
- Android Studio (SDK & Platform Tools), ADB in PATH
- Samsung mit aktivem USB-Debugging

## Schnellstart
```bash
unzip mobidata-bw-flutterer.zip
cd mobidata-bw-flutterer
flutter pub get
flutter run
```

## Inhalt
- `flutter_map` + OSM Tiles
- Service `MobiDataApi` (Dio) ruft `https://api.mobidata-bw.de/park-api/api/public/v3/parking-sites` ab
- Einfaches BBox-Filtering am Client (für Produktion: Server-Clippen empfohlen)
- Standortfreigabe (optional), Marker, Bottom Sheet

## Todos
- GBFS-Integration (Car/Bike/Scooter)
- Server-BFF für BBox/Polygon-Filter & Caching
- UI-Filter (nur freie Plätze, Ladesäulen etc.)
- iOS-Build via Xcode, wenn benötigt
```

