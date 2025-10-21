import 'package:flutter_test/flutter_test.dart';
import 'package:owntrack/data/datasources/local/preferences/settings_local_datasource.dart';
import 'package:owntrack/data/models/waypoint.dart';
import 'package:owntrack/data/repositories/waypoints_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('WaypointsRepository', () {
    late WaypointsRepository repository;
    late SettingsLocalDataSource dataSource;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      dataSource = SettingsLocalDataSource(prefs);
      repository = WaypointsRepository(dataSource);
    });

    test('should start with empty waypoints', () {
      expect(repository.count, equals(0));
      expect(repository.getAllWaypoints(), isEmpty);
    });

    test('should add waypoint', () async {
      const waypoint = Waypoint(
        id: 'waypoint1',
        lat: 37.7749,
        lon: -122.4194,
        timestamp: 1704110400,
        description: 'Test Waypoint',
      );

      await repository.addWaypoint(waypoint);

      expect(repository.count, equals(1));
      expect(repository.getWaypoint('waypoint1'), equals(waypoint));
    });

    test('should persist waypoints', () async {
      const waypoint = Waypoint(
        id: 'waypoint1',
        lat: 37.7749,
        lon: -122.4194,
        timestamp: 1704110400,
        description: 'Test Waypoint',
      );

      await repository.addWaypoint(waypoint);

      // Create new repository with same data source
      final newRepository = WaypointsRepository(dataSource);

      expect(newRepository.count, equals(1));
      expect(newRepository.getWaypoint('waypoint1'), isNotNull);
      expect(newRepository.getWaypoint('waypoint1')?.description, equals('Test Waypoint'));
    });

    test('should update waypoint', () async {
      const waypoint = Waypoint(
        id: 'waypoint1',
        lat: 37.7749,
        lon: -122.4194,
        timestamp: 1704110400,
        description: 'Test Waypoint',
      );

      await repository.addWaypoint(waypoint);

      final updated = waypoint.copyWith(description: 'Updated Waypoint');
      await repository.updateWaypoint(updated);

      expect(repository.getWaypoint('waypoint1')?.description, equals('Updated Waypoint'));
    });

    test('should delete waypoint', () async {
      const waypoint = Waypoint(
        id: 'waypoint1',
        lat: 37.7749,
        lon: -122.4194,
        timestamp: 1704110400,
      );

      await repository.addWaypoint(waypoint);
      await repository.deleteWaypoint('waypoint1');

      expect(repository.count, equals(0));
      expect(repository.getWaypoint('waypoint1'), isNull);
    });

    test('should get all waypoints', () async {
      const waypoint1 = Waypoint(
        id: 'waypoint1',
        lat: 37.7749,
        lon: -122.4194,
        timestamp: 1704110400,
      );

      const waypoint2 = Waypoint(
        id: 'waypoint2',
        lat: 38.0000,
        lon: -122.5000,
        timestamp: 1704110500,
      );

      await repository.addWaypoint(waypoint1);
      await repository.addWaypoint(waypoint2);

      final waypoints = repository.getAllWaypoints();
      expect(waypoints.length, equals(2));
    });

    test('should clear all waypoints', () async {
      const waypoint1 = Waypoint(
        id: 'waypoint1',
        lat: 37.7749,
        lon: -122.4194,
        timestamp: 1704110400,
      );

      const waypoint2 = Waypoint(
        id: 'waypoint2',
        lat: 38.0000,
        lon: -122.5000,
        timestamp: 1704110500,
      );

      await repository.addWaypoint(waypoint1);
      await repository.addWaypoint(waypoint2);

      await repository.clearAll();

      expect(repository.count, equals(0));
      expect(repository.getAllWaypoints(), isEmpty);
    });
  });
}
