import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:owntrack/data/services/permission_service.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _PermissionGeolocator extends GeolocatorPlatform
    with MockPlatformInterfaceMixin {
  LocationPermission permission = LocationPermission.denied;
  LocationPermission requestedPermission = LocationPermission.denied;
  int checks = 0;
  int requests = 0;

  @override
  Future<LocationPermission> checkPermission() async {
    checks++;
    return permission;
  }

  @override
  Future<LocationPermission> requestPermission() async {
    requests++;
    return permission = requestedPermission;
  }

  @override
  Future<bool> isLocationServiceEnabled() async => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final originalGeolocator = GeolocatorPlatform.instance;
  const permissionChannel = MethodChannel(
    'flutter.baseflow.com/permissions/methods',
  );
  group('PermissionService', () {
    late PermissionService service;
    late _PermissionGeolocator geolocator;
    late List<List<int>> nativeRequests;
    late ph.PermissionStatus alwaysResult;
    void Function()? afterAlwaysRequest;

    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      geolocator = _PermissionGeolocator();
      GeolocatorPlatform.instance = geolocator;
      nativeRequests = [];
      alwaysResult = ph.PermissionStatus.denied;
      afterAlwaysRequest = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(permissionChannel, (call) async {
            if (call.method == 'requestPermissions') {
              final requested = List<int>.from(call.arguments as List);
              nativeRequests.add(requested);
              expect(requested, [ph.Permission.locationAlways.value]);
              afterAlwaysRequest?.call();
              return {ph.Permission.locationAlways.value: alwaysResult.index};
            }
            throw StateError(
              'Unexpected permission channel call: ${call.method}',
            );
          });
      service = PermissionService();
    });

    tearDown(() {
      GeolocatorPlatform.instance = originalGeolocator;
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(permissionChannel, null);
    });

    group('iOS background permission', () {
      setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.iOS);

      for (final permission in LocationPermission.values) {
        test('check distinguishes $permission from always', () async {
          geolocator.permission = permission;
          expect(
            await service.checkBackgroundLocationPermission(),
            permission == LocationPermission.always,
          );
          expect(geolocator.checks, 1);
          expect(nativeRequests, isEmpty);
        });
      }

      test('when-in-use grants foreground but not background access', () async {
        geolocator.permission = LocationPermission.whileInUse;
        expect(
          await service.checkLocationPermission(),
          AppPermissionStatus.granted,
        );
        expect(await service.checkBackgroundLocationPermission(), isFalse);
        expect(geolocator.checks, 2);
      });

      test('existing always grant does not request permission again', () async {
        geolocator.permission = LocationPermission.always;
        expect(
          await service.requestBackgroundLocationPermission(),
          AppPermissionStatus.granted,
        );
        expect(geolocator.requests, 0);
        expect(nativeRequests, isEmpty);
      });

      test('when-in-use upgrades through the native always request', () async {
        geolocator.permission = LocationPermission.whileInUse;
        alwaysResult = ph.PermissionStatus.granted;
        afterAlwaysRequest = () {
          geolocator.permission = LocationPermission.always;
        };
        expect(
          await service.requestBackgroundLocationPermission(),
          AppPermissionStatus.granted,
        );
        expect(nativeRequests, [
          [ph.Permission.locationAlways.value],
        ]);
        expect(geolocator.requests, 0);
        expect(geolocator.checks, 2);
      });

      test(
        'foreground is requested before upgrading undetermined access',
        () async {
          geolocator.requestedPermission = LocationPermission.whileInUse;
          alwaysResult = ph.PermissionStatus.granted;
          afterAlwaysRequest = () {
            expect(geolocator.requests, 1);
            expect(geolocator.permission, LocationPermission.whileInUse);
            geolocator.permission = LocationPermission.always;
          };
          expect(
            await service.requestBackgroundLocationPermission(),
            AppPermissionStatus.granted,
          );
          expect(nativeRequests, [
            [ph.Permission.locationAlways.value],
          ]);
          expect(geolocator.requests, 1);
        },
      );

      test('foreground denial does not request always authorization', () async {
        expect(
          await service.requestBackgroundLocationPermission(),
          AppPermissionStatus.denied,
        );
        expect(geolocator.requests, 1);
        expect(nativeRequests, isEmpty);
      });

      test(
        'permanent foreground denial is preserved without another prompt',
        () async {
          geolocator.permission = LocationPermission.deniedForever;
          expect(
            await service.requestBackgroundLocationPermission(),
            AppPermissionStatus.permanentlyDenied,
          );
          expect(geolocator.requests, 0);
          expect(nativeRequests, isEmpty);
        },
      );

      test(
        'a granted request is checked against actual always authorization',
        () async {
          geolocator.permission = LocationPermission.whileInUse;
          alwaysResult = ph.PermissionStatus.granted;
          expect(
            await service.requestBackgroundLocationPermission(),
            AppPermissionStatus.denied,
          );
          expect(nativeRequests, [
            [ph.Permission.locationAlways.value],
          ]);
          expect(geolocator.checks, 2);
        },
      );

      final refusals = {
        ph.PermissionStatus.denied: AppPermissionStatus.denied,
        ph.PermissionStatus.permanentlyDenied:
            AppPermissionStatus.permanentlyDenied,
        ph.PermissionStatus.restricted: AppPermissionStatus.restricted,
      };
      for (final refusal in refusals.entries) {
        test(
          'always request reports ${refusal.key} without foreground conflation',
          () async {
            geolocator.permission = LocationPermission.whileInUse;
            alwaysResult = refusal.key;
            expect(
              await service.requestBackgroundLocationPermission(),
              refusal.value,
            );
            expect(nativeRequests, [
              [ph.Permission.locationAlways.value],
            ]);
          },
        );
      }
    });

    test(
      'desktop background checks never invoke either native permission API',
      () async {
        expect(await service.checkBackgroundLocationPermission(), isFalse);
        expect(
          await service.requestBackgroundLocationPermission(),
          AppPermissionStatus.denied,
        );
        expect(geolocator.checks, 0);
        expect(geolocator.requests, 0);
        expect(nativeRequests, isEmpty);
      },
    );

    group('AppPermissionStatus', () {
      test('should have correct enum values', () {
        expect(AppPermissionStatus.values.length, equals(4));
        expect(AppPermissionStatus.granted, isA<AppPermissionStatus>());
        expect(AppPermissionStatus.denied, isA<AppPermissionStatus>());
        expect(
          AppPermissionStatus.permanentlyDenied,
          isA<AppPermissionStatus>(),
        );
        expect(AppPermissionStatus.restricted, isA<AppPermissionStatus>());
      });
    });

    group('checkLocationPermission', () {
      test('should return permission status', () async {
        final status = await service.checkLocationPermission();
        expect(status, isA<AppPermissionStatus>());
      });
    });

    group('checkNotificationPermission', () {
      test('should return permission status', () async {
        final status = await service.checkNotificationPermission();
        expect(status, isA<AppPermissionStatus>());
      });
    });

    group('isLocationServiceEnabled', () {
      test('should return boolean', () async {
        final enabled = await service.isLocationServiceEnabled();
        expect(enabled, isA<bool>());
      });
    });

    group('requestAllPermissions', () {
      test('should return map of permission statuses', () async {
        final results = await service.requestAllPermissions();
        expect(results, isA<Map<String, AppPermissionStatus>>());
        expect(results.containsKey('location'), isTrue);
        expect(results.containsKey('notification'), isTrue);
      });
    });
  });
}
