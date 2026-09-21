import 'dart:async';
import 'package:owntrack/core/constants/app_constants.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:owntrack/data/datasources/local/preferences/settings_local_datasource.dart';
import 'package:owntrack/data/repositories/settings_repository.dart';
import 'package:owntrack/data/services/location_service.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

Position _position() => Position(
  latitude: 40.2141,
  longitude: -111.6711,
  timestamp: DateTime.fromMillisecondsSinceEpoch(1704110400000),
  accuracy: 35,
  altitude: 1400,
  altitudeAccuracy: 10,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

/// Scripted stand-in for the geolocator platform, reproducing the macOS
/// authorization race: requestPermission resolves granted, but the very next
/// getCurrentPosition still sees the stale denial inside the plugin.
class _FakeGeolocatorPlatform extends GeolocatorPlatform
    with MockPlatformInterfaceMixin {
  _FakeGeolocatorPlatform({
    required this.permissionSequence,
    required this.positionResults,
  });

  /// Values returned by successive checkPermission calls (last one repeats).
  final List<LocationPermission> permissionSequence;

  /// One entry per getCurrentPosition call: a [Position] to return or an
  /// exception to throw (last one repeats).
  final List<Object> positionResults;

  final positions = StreamController<Position>.broadcast();
  LocationSettings? streamSettings;
  LocationSettings? oneShotSettings;
  int streamCalls = 0;
  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) {
    streamCalls++;
    streamSettings = locationSettings;
    return positions.stream;
  }

  int checkPermissionCalls = 0;
  int requestPermissionCalls = 0;
  int getCurrentPositionCalls = 0;

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async {
    final i = checkPermissionCalls++;
    return permissionSequence[i < permissionSequence.length
        ? i
        : permissionSequence.length - 1];
  }

  @override
  Future<LocationPermission> requestPermission() async {
    requestPermissionCalls++;
    return LocationPermission.always;
  }

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    oneShotSettings = locationSettings;
    final i = getCurrentPositionCalls++;
    final scripted =
        positionResults[i < positionResults.length
            ? i
            : positionResults.length - 1];
    if (scripted is Position) return scripted;
    // ignore: only_throw_errors
    throw scripted;
  }
}

Future<LocationService> _service() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return LocationService(SettingsRepository(SettingsLocalDataSource(prefs)));
}

void main() {
  final originalPlatform = GeolocatorPlatform.instance;
  tearDown(() => GeolocatorPlatform.instance = originalPlatform);
  group('monitoring lifecycle', () {
    late _FakeGeolocatorPlatform platform;
    late SettingsRepository settings;
    late LocationService service;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      settings = SettingsRepository(
        SettingsLocalDataSource(await SharedPreferences.getInstance()),
      );
      platform = _FakeGeolocatorPlatform(
        permissionSequence: [LocationPermission.always],
        positionResults: [_position()],
      );
      GeolocatorPlatform.instance = platform;
      service = LocationService(settings);
    });
    tearDown(() async {
      await service.stopTracking();
      service.dispose();
      await platform.positions.close();
    });
    for (final mode in [
      AppConstants.monitoringModeQuiet,
      AppConstants.monitoringModeManual,
    ]) {
      test('mode $mode never requests automatic location updates', () async {
        await settings.setMonitoringMode(mode);
        expect(await service.startTracking(), isTrue);
        expect(platform.streamCalls, 0);
        expect(platform.checkPermissionCalls, 0);
        expect(service.isTracking, isFalse);
      });
    }
    for (final mode in [
      AppConstants.monitoringModeSignificant,
      AppConstants.monitoringModeMove,
    ]) {
      test('mode $mode does not cancel tracking when stationary', () async {
        await settings.setMonitoringMode(mode);
        expect(await service.startTracking(), isTrue);
        expect(platform.streamSettings!.timeLimit, isNull);
      });
    }
    test('repeated start owns exactly one GPS subscription', () async {
      await Future.wait([service.startTracking(), service.startTracking()]);
      expect(platform.streamCalls, 1);
      await service.stopTracking();
      expect(platform.positions.hasListener, isFalse);
    });
    test('stream errors reach consumers and clear active state', () async {
      await service.startTracking();
      final error = service.locationUpdates.first;
      platform.positions.addError(const LocationServiceDisabledException());
      await expectLater(
        error,
        throwsA(isA<LocationServiceDisabledException>()),
      );
      expect(service.isTracking, isFalse);
    });
    test('one-shot acquisition has a finite deadline', () async {
      expect(await service.getCurrentLocation(), isNotNull);
      expect(platform.oneShotSettings!.timeLimit, const Duration(seconds: 30));
    });
  });
  group('LocationService.getCurrentLocation', () {
    test('retries when the first read hits the stale-denial race right after '
        'permission is granted', () async {
      // Reproduces the observed macOS sequence: checkPermission=denied,
      // requestPermission=always, then getCurrentPosition throws
      // PermissionDeniedException anyway; a moment later the same call works.
      final fake = _FakeGeolocatorPlatform(
        permissionSequence: const [
          LocationPermission.denied, // initial check
          LocationPermission.always, // any re-checks after the grant
        ],
        positionResults: [
          const PermissionDeniedException('stale authorization'),
          _position(),
        ],
      );
      GeolocatorPlatform.instance = fake;

      final update = await (await _service()).getCurrentLocation();

      expect(
        update,
        isNotNull,
        reason: 'first tap after granting permission must succeed',
      );
      expect(update!.latitude, closeTo(40.2141, 1e-9));
      expect(fake.getCurrentPositionCalls, 2);
    });

    test('gives up after bounded retries when the denial is real', () async {
      final fake = _FakeGeolocatorPlatform(
        permissionSequence: const [
          LocationPermission.denied,
          LocationPermission.always,
        ],
        positionResults: const [PermissionDeniedException('still denied')],
      );
      GeolocatorPlatform.instance = fake;

      final update = await (await _service()).getCurrentLocation();

      expect(update, isNull);
      expect(
        fake.getCurrentPositionCalls,
        lessThanOrEqualTo(3),
        reason: 'must not retry unboundedly',
      );
    });

    test('does not retry when permission was denied outright', () async {
      final fake = _FakeGeolocatorPlatform(
        permissionSequence: const [LocationPermission.denied],
        positionResults: [_position()],
      );
      GeolocatorPlatform.instance = fake;
      // Deny the request too.
      final denying = _DenyingPlatform();
      GeolocatorPlatform.instance = denying;

      final update = await (await _service()).getCurrentLocation();

      expect(update, isNull);
      expect(
        denying.getCurrentPositionCalls,
        0,
        reason: 'no position read should be attempted without permission',
      );
    });

    test('succeeds without retrying when there is no race', () async {
      final fake = _FakeGeolocatorPlatform(
        permissionSequence: const [LocationPermission.always],
        positionResults: [_position()],
      );
      GeolocatorPlatform.instance = fake;

      final update = await (await _service()).getCurrentLocation();

      expect(update, isNotNull);
      expect(fake.getCurrentPositionCalls, 1);
      expect(fake.requestPermissionCalls, 0);
    });
  });
}

class _DenyingPlatform extends GeolocatorPlatform
    with MockPlatformInterfaceMixin {
  int getCurrentPositionCalls = 0;

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.denied;

  @override
  Future<LocationPermission> requestPermission() async =>
      LocationPermission.denied;

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    getCurrentPositionCalls++;
    return _position();
  }
}
