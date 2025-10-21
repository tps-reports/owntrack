import 'package:flutter_test/flutter_test.dart';
import 'package:owntrack/data/services/permission_service.dart';

void main() {
  group('PermissionService', () {
    late PermissionService service;

    setUp(() {
      service = PermissionService();
    });

    group('AppPermissionStatus', () {
      test('should have correct enum values', () {
        expect(AppPermissionStatus.values.length, equals(4));
        expect(AppPermissionStatus.granted, isA<AppPermissionStatus>());
        expect(AppPermissionStatus.denied, isA<AppPermissionStatus>());
        expect(AppPermissionStatus.permanentlyDenied, isA<AppPermissionStatus>());
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
