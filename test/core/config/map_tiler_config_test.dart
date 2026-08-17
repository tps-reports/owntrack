import 'package:flutter_test/flutter_test.dart';
import 'package:owntrack/core/config/map_tiler_config.dart';

void main() {
  group('MapTilerConfig', () {
    test('is not configured when the key is empty', () {
      const config = MapTilerConfig(apiKey: '');

      expect(config.isConfigured, isFalse);
    });

    test('treats a whitespace-only key as unconfigured', () {
      const config = MapTilerConfig(apiKey: '   ');

      expect(config.isConfigured, isFalse);
    });

    test('is configured when a key is supplied', () {
      const config = MapTilerConfig(apiKey: 'abc123');

      expect(config.isConfigured, isTrue);
    });

    test('builds a MapTiler raster url template carrying the key', () {
      const config = MapTilerConfig(apiKey: 'abc123');

      expect(
        config.urlTemplate,
        'https://api.maptiler.com/maps/outdoor-v2/{z}/{x}/{y}@2x.png'
        '?key=abc123',
      );
    });

    test('honours a non-default style', () {
      const config = MapTilerConfig(apiKey: 'abc123', style: 'streets-v2');

      expect(config.urlTemplate, contains('/maps/streets-v2/'));
    });

    test('leaves the flutter_map placeholders unsubstituted', () {
      const config = MapTilerConfig(apiKey: 'abc123');

      // flutter_map fills these in per tile; they must survive verbatim.
      expect(config.urlTemplate, contains('{z}'));
      expect(config.urlTemplate, contains('{x}'));
      expect(config.urlTemplate, contains('{y}'));
    });

    test('throws rather than emitting a keyless url when unconfigured', () {
      const config = MapTilerConfig(apiKey: '');

      expect(() => config.urlTemplate, throwsStateError);
    });
  });

  group('MapTilerConfig.resolveKey', () {
    test('a direct MAPS_API_KEY define wins over everything', () {
      final key = MapTilerConfig.resolveKey(
        direct: 'direct-key',
        fivexConfig: 'https://dev.2h2.us?maps_key=anvil-key&env=local',
      );

      expect(key, 'direct-key');
    });

    test('falls back to maps_key parsed from FIVEX_CONFIG', () {
      final key = MapTilerConfig.resolveKey(
        direct: '',
        fivexConfig:
            'https://dev.2h2.us:443?mqtt_host=localhost&maps_key=anvil-key'
            '&rp_id=dev.2h2.us&env=local',
      );

      expect(key, 'anvil-key');
    });

    test('is empty when FIVEX_CONFIG has no maps_key', () {
      final key = MapTilerConfig.resolveKey(
        direct: '',
        fivexConfig: 'https://dev.2h2.us?env=local',
      );

      expect(key, isEmpty);
    });

    test('is empty when neither source is set', () {
      final key = MapTilerConfig.resolveKey(direct: '', fivexConfig: '');

      expect(key, isEmpty);
    });

    test('tolerates an unparseable FIVEX_CONFIG', () {
      final key = MapTilerConfig.resolveKey(
        direct: '',
        fivexConfig: '::not a url::',
      );

      expect(key, isEmpty);
    });
  });
}
