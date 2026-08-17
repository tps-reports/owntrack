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
  ///
  /// Two sources, in priority order:
  ///  1. the `MAPS_API_KEY` dart-define;
  ///  2. the `maps_key` query parameter of the `FIVEX_CONFIG` dart-define —
  ///     the URL anvil's dev_runner passes from `.anvil`'s
  ///     `environments.<env>.config_url`, where the key is carried as a
  ///     `${MAPS_API_KEY}` placeholder expanded from the shell environment
  ///     at launch time so the tracked file never contains the value.
  factory MapTilerConfig.fromEnvironment() => MapTilerConfig(
        apiKey: resolveKey(direct: _envApiKey, fivexConfig: _envFivexConfig),
      );

  /// Resolution logic for [MapTilerConfig.fromEnvironment], kept pure so
  /// every branch is unit-testable.
  static String resolveKey({
    required String direct,
    required String fivexConfig,
  }) {
    if (direct.trim().isNotEmpty) return direct.trim();
    if (fivexConfig.trim().isEmpty) return '';

    final uri = Uri.tryParse(fivexConfig.trim());
    if (uri == null) return '';
    return uri.queryParameters['maps_key']?.trim() ?? '';
  }

  /// Terrain-oriented style, suited to a location tracker used outdoors.
  static const String defaultStyle = 'outdoor-v2';

  /// Name of the dart-define carrying the key.
  static const String envVarName = 'MAPS_API_KEY';

  static const String _envApiKey = String.fromEnvironment(envVarName);

  static const String _envFivexConfig = String.fromEnvironment('FIVEX_CONFIG');

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
