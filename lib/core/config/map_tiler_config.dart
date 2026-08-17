/// MapTiler raster tile configuration.
///
/// The OpenStreetMap Foundation's public tile servers (`tile.openstreetmap.org`)
/// are donation-funded and their usage policy forbids distributed applications,
/// so tiles are served by MapTiler instead.
///
/// The API key is supplied at build time:
///
/// ```sh
/// flutter run --dart-define=MAPS_API_KEY=$MAPS_API_KEY
/// flutter build web --release --dart-define=MAPS_API_KEY=$MAPS_API_KEY
/// ```
///
/// or via a git-ignored defines file:
///
/// ```sh
/// flutter run --dart-define-from-file=dart_defines.json
/// ```
///
/// [String.fromEnvironment] is resolved by the compiler, not at runtime, so a
/// shell variable alone is not enough — it must be forwarded as a dart-define.
/// The key is injected as a constructor argument rather than read inline so
/// that every branch here stays unit-testable.
///
/// Note that a client-side tile key is necessarily present in the shipped
/// bundle. Restrict it by allowed origin in the MapTiler dashboard; the key
/// itself is not a secret once the app is distributed.
class MapTilerConfig {
  const MapTilerConfig({
    required this.apiKey,
    this.style = defaultStyle,
  });

  /// Reads the key from the compile-time environment.
  factory MapTilerConfig.fromEnvironment() =>
      const MapTilerConfig(apiKey: _envApiKey);

  /// Terrain-oriented style, suited to a location tracker used outdoors.
  static const String defaultStyle = 'outdoor-v2';

  /// Name of the dart-define carrying the key.
  static const String envVarName = 'MAPS_API_KEY';

  static const String _envApiKey = String.fromEnvironment(envVarName);

  final String apiKey;
  final String style;

  /// True when a usable key was supplied at build time.
  bool get isConfigured => apiKey.trim().isNotEmpty;

  /// Tile URL template for `TileLayer.urlTemplate`.
  ///
  /// The `{z}` / `{x}` / `{y}` placeholders are filled in by flutter_map per
  /// tile and must survive verbatim.
  ///
  /// Throws [StateError] when no key is configured, so a keyless request is
  /// never issued — MapTiler answers those with 403 and the map would degrade
  /// to a blank grid with nothing explaining why.
  String get urlTemplate {
    if (!isConfigured) {
      throw StateError(
        'MapTiler API key missing. Pass --dart-define=$envVarName=<key> '
        'when building or running the app.',
      );
    }

    return 'https://api.maptiler.com/maps/$style/{z}/{x}/{y}@2x.png'
        '?key=${apiKey.trim()}';
  }
}
