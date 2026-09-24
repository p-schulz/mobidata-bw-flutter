import 'package:flutter/foundation.dart' show kIsWeb;

/// URLs of the self-hosted backend (mobidata-bw-flutter-backend).
///
/// Everything is routed through the backend's nginx on port 80/443:
///   /api/     TRIAS proxy (transit, geocoding)
///   /styles/  map style JSONs
///   /tiles/   PMTiles vector tiles (referenced from the styles)
///
/// The web build is served by that same nginx, so it uses its own origin.
/// This avoids extra ports, CORS and mixed content when the site moves to
/// HTTPS. Override with `--dart-define=BACKEND_URL=https://example.org`, e.g.
/// for `flutter run -d chrome`, whose localhost origin has no backend.
class BackendConfig {
  BackendConfig._();

  static const _defaultServerUrl = 'http://85.215.128.121';
  static const _serverUrlOverride = String.fromEnvironment('BACKEND_URL');

  static String get serverUrl {
    if (_serverUrlOverride.isNotEmpty) return _serverUrlOverride;
    if (kIsWeb) return Uri.base.origin;
    return _defaultServerUrl;
  }

  static String get apiBaseUrl => '$serverUrl/api';
  static String get stylesBaseUrl => '$serverUrl/styles';

  // Shipped in every build (and readable in the web build's JS), so this only
  // keeps out casual traffic; it is not a secret.
  static const apiKey =
      'a9f88d7fe78f3e1dcdecc6e22c818c43f4d71fe549d4a28aac2d7892c8be6a2e';

  /// Radnetz needs SQLite and a 150 MB GeoPackage download, which the web
  /// build can't do.
  static const bicycleNetworkSupported = !kIsWeb;
}
