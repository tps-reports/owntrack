import 'package:flutter_test/flutter_test.dart';
import 'package:owntrack/data/datasources/local/preferences/settings_local_datasource.dart';
import 'package:owntrack/data/models/region.dart';
import 'package:owntrack/data/repositories/regions_repository.dart';
import 'package:owntrack/data/services/geofencing_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('GeofencingService', () {
    late GeofencingService service;
    late RegionsRepository regionsRepository;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final dataSource = SettingsLocalDataSource(prefs);
      regionsRepository = RegionsRepository(dataSource);
      service = GeofencingService(regionsRepository);
    });

    tearDown(() {
      service.dispose();
    });

    group('region management', () {
      test('should add region', () async {
        const region = Region(
          id: 'home',
          lat: 37.7749,
          lon: -122.4194,
          radius: 100,
          description: 'Home',
          enabled: true,
          timestamp: 1704110400,
        );

        await service.addRegion(region);

        final regions = service.getAllRegions();
        expect(regions.length, equals(1));
        expect(regions.first.id, equals('home'));
      });

      test('should remove region', () async {
        const region = Region(
          id: 'home',
          lat: 37.7749,
          lon: -122.4194,
          radius: 100,
          enabled: true,
          timestamp: 1704110400,
        );

        await service.addRegion(region);
        await service.removeRegion('home');

        final regions = service.getAllRegions();
        expect(regions.length, equals(0));
      });

      test('should update region', () async {
        const region = Region(
          id: 'home',
          lat: 37.7749,
          lon: -122.4194,
          radius: 100,
          description: 'Home',
          enabled: true,
          timestamp: 1704110400,
        );

        await service.addRegion(region);

        final updated = region.copyWith(description: 'Updated Home');
        await service.updateRegion(updated);

        final regions = service.getAllRegions();
        expect(regions.first.description, equals('Updated Home'));
      });

      test('should enable region', () async {
        const region = Region(
          id: 'home',
          lat: 37.7749,
          lon: -122.4194,
          radius: 100,
          enabled: false,
          timestamp: 1704110400,
        );

        await service.addRegion(region);
        await service.enableRegion('home');

        final regions = service.getEnabledRegions();
        expect(regions.length, equals(1));
      });

      test('should disable region', () async {
        const region = Region(
          id: 'home',
          lat: 37.7749,
          lon: -122.4194,
          radius: 100,
          enabled: true,
          timestamp: 1704110400,
        );

        await service.addRegion(region);
        await service.disableRegion('home');

        final regions = service.getEnabledRegions();
        expect(regions.length, equals(0));
      });
    });

    group('geofence transitions', () {
      test('should detect entry into region', () async {
        const region = Region(
          id: 'home',
          lat: 37.7749,
          lon: -122.4194,
          radius: 100,
          enabled: true,
          timestamp: 1704110400,
        );

        await service.addRegion(region);

        final transitions = <GeofenceTransition>[];
        service.transitions.listen(transitions.add);

        // Check location inside region
        await service.checkLocation(37.7749, -122.4194);

        await Future.delayed(const Duration(milliseconds: 100));

        expect(transitions.length, equals(1));
        expect(transitions.first.event, equals(GeofenceEvent.enter));
        expect(transitions.first.region.id, equals('home'));
      });

      test('should detect exit from region', () async {
        const region = Region(
          id: 'home',
          lat: 37.7749,
          lon: -122.4194,
          radius: 100,
          enabled: true,
          timestamp: 1704110400,
        );

        await service.addRegion(region);

        final transitions = <GeofenceTransition>[];
        service.transitions.listen(transitions.add);

        // Enter region
        await service.checkLocation(37.7749, -122.4194);
        await Future.delayed(const Duration(milliseconds: 100));

        // Exit region
        await service.checkLocation(38.0, -122.5);
        await Future.delayed(const Duration(milliseconds: 100));

        expect(transitions.length, equals(2));
        expect(transitions[0].event, equals(GeofenceEvent.enter));
        expect(transitions[1].event, equals(GeofenceEvent.exit));
      });

      test('should not trigger transition if staying inside region', () async {
        const region = Region(
          id: 'home',
          lat: 37.7749,
          lon: -122.4194,
          radius: 100,
          enabled: true,
          timestamp: 1704110400,
        );

        await service.addRegion(region);

        final transitions = <GeofenceTransition>[];
        service.transitions.listen(transitions.add);

        // Enter region
        await service.checkLocation(37.7749, -122.4194);
        await Future.delayed(const Duration(milliseconds: 100));

        // Still inside region
        await service.checkLocation(37.7750, -122.4195);
        await Future.delayed(const Duration(milliseconds: 100));

        expect(transitions.length, equals(1)); // Only entry
      });
    });

    group('current regions', () {
      test('should track current regions', () async {
        const region = Region(
          id: 'home',
          lat: 37.7749,
          lon: -122.4194,
          radius: 100,
          enabled: true,
          timestamp: 1704110400,
        );

        await service.addRegion(region);

        // Outside region
        expect(service.isInsideRegion('home'), isFalse);

        // Enter region
        await service.checkLocation(37.7749, -122.4194);
        await Future.delayed(const Duration(milliseconds: 100));

        expect(service.isInsideRegion('home'), isTrue);
        expect(service.getCurrentRegions(), contains('home'));
      });
    });

    group('clear all', () {
      test('should clear all regions', () async {
        const region1 = Region(
          id: 'home',
          lat: 37.7749,
          lon: -122.4194,
          radius: 100,
          enabled: true,
          timestamp: 1704110400,
        );

        const region2 = Region(
          id: 'work',
          lat: 37.7849,
          lon: -122.4294,
          radius: 100,
          enabled: true,
          timestamp: 1704110400,
        );

        await service.addRegion(region1);
        await service.addRegion(region2);

        expect(service.getAllRegions().length, equals(2));

        await service.clearAllRegions();

        expect(service.getAllRegions().length, equals(0));
      });
    });
  });
}
