import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
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
      test('initial occupancy does not enqueue a manufactured entry', () async {
        await service.addRegion(
          const Region(id: 'home', lat: 1, lon: 2, radius: 100),
        );
        final accepted = <GeofenceTransition>[];
        await service.checkLocation(
          1,
          2,
          acceptTransition: (transition) async {
            accepted.add(transition);
          },
        );
        expect(accepted, isEmpty);
        expect(service.isInsideRegion('home'), isTrue);
      });

      test(
        'failed acceptance retains the crossing before a later exit',
        () async {
          await service.addRegion(
            const Region(id: 'home', lat: 1, lon: 2, radius: 100),
          );
          final observed = <GeofenceTransition>[];
          final attempts = <GeofenceTransition>[];
          service.transitions.listen(observed.add);
          Future<void> accept(GeofenceTransition transition) async {
            attempts.add(transition);
            if (attempts.length <= 2) throw StateError('Outbox unavailable');
          }

          await service.checkLocation(
            1.01,
            2,
            timestamp: 100,
            acceptTransition: accept,
          );
          await expectLater(
            service.checkLocation(
              1,
              2,
              timestamp: 101,
              acceptTransition: accept,
            ),
            throwsStateError,
          );
          expect(service.isInsideRegion('home'), isFalse);
          await expectLater(
            service.checkLocation(
              1.01,
              2,
              timestamp: 102,
              acceptTransition: accept,
            ),
            throwsStateError,
          );
          await pumpEventQueue();
          expect(observed, isEmpty);
          expect(attempts.map((transition) => transition.event), [
            GeofenceEvent.enter,
            GeofenceEvent.enter,
          ]);
          await service.checkLocation(
            1.01,
            2,
            timestamp: 103,
            acceptTransition: accept,
          );
          await pumpEventQueue();
          expect(attempts.map((transition) => transition.timestamp), [
            101,
            101,
            101,
            103,
          ]);
          expect(identical(attempts[0], attempts[2]), isTrue);
          expect(observed.map((transition) => transition.event), [
            GeofenceEvent.enter,
            GeofenceEvent.exit,
          ]);
          expect(service.isInsideRegion('home'), isFalse);
        },
      );

      test(
        'concurrent checks await acceptance without duplicate queue insertions',
        () async {
          await service.addRegion(
            const Region(id: 'home', lat: 1, lon: 2, radius: 100),
          );
          await service.checkLocation(1.01, 2);
          final queued = Completer<void>();
          var calls = 0;
          Future<void> accept(GeofenceTransition transition) async {
            calls++;
            await queued.future;
          }

          final first = service.checkLocation(1, 2, acceptTransition: accept);
          final second = service.checkLocation(1, 2, acceptTransition: accept);
          await pumpEventQueue();
          expect(calls, 1);
          expect(service.isInsideRegion('home'), isFalse);
          queued.complete();
          await Future.wait([first, second]);
          expect(calls, 1);
          expect(service.isInsideRegion('home'), isTrue);
        },
      );

      for (final failBoth in [false, true]) {
        test(
          'overlapping regions retain independent crossing histories when '
          '${failBoth ? 'both regions fail' : 'the first region fails'}',
          () async {
            await service.addRegion(
              const Region(id: 'first', lat: 1, lon: 2, radius: 100),
            );
            await service.addRegion(
              const Region(id: 'second', lat: 1, lon: 2, radius: 200),
            );
            final attempts = <String, int>{};
            final accepted = <GeofenceTransition>[];
            Future<void> accept(GeofenceTransition transition) async {
              final id = transition.region.id;
              attempts[id] = (attempts[id] ?? 0) + 1;
              if (attempts[id] == 1 && (failBoth || id == 'first')) {
                throw StateError('Outbox temporarily unavailable');
              }
              accepted.add(transition);
            }

            await service.checkLocation(
              1.01,
              2,
              timestamp: 100,
              acceptTransition: accept,
            );
            await expectLater(
              service.checkLocation(
                1,
                2,
                timestamp: 101,
                acceptTransition: accept,
              ),
              throwsStateError,
            );
            await service.checkLocation(
              1.01,
              2,
              timestamp: 102,
              acceptTransition: accept,
            );

            for (final id in ['first', 'second']) {
              final history = accepted.where((event) => event.region.id == id);
              expect(history.map((event) => event.event), [
                GeofenceEvent.enter,
                GeofenceEvent.exit,
              ], reason: id);
              expect(history.map((event) => event.timestamp), [
                101,
                102,
              ], reason: id);
              expect(history.map((event) => event.latitude), [
                1,
                1.01,
              ], reason: id);
              expect(service.isInsideRegion(id), isFalse);
            }
          },
        );
      }

      test(
        'repository edits reset pending crossings for the old region',
        () async {
          const home = Region(id: 'home', lat: 1, lon: 2, radius: 100);
          await service.addRegion(home);
          await service.checkLocation(1.01, 2);
          await expectLater(
            service.checkLocation(
              1,
              2,
              acceptTransition: (_) async {
                throw StateError('Outbox unavailable');
              },
            ),
            throwsStateError,
          );
          await regionsRepository.updateRegion(home.copyWith(lat: 2));
          final accepted = <GeofenceTransition>[];
          await service.checkLocation(
            1,
            2,
            acceptTransition: (transition) async {
              accepted.add(transition);
            },
          );
          expect(accepted, isEmpty);
          expect(service.isInsideRegion('home'), isFalse);
        },
      );

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

        await service.checkLocation(38.0, -122.5);

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

        await service.checkLocation(38.0, -122.5);

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

        await service.checkLocation(38.0, -122.5);

        // Enter region
        await service.checkLocation(37.7749, -122.4194);
        await Future.delayed(const Duration(milliseconds: 100));

        // Still inside region
        await service.checkLocation(37.7750, -122.4195);
        await Future.delayed(const Duration(milliseconds: 100));

        expect(transitions.length, equals(1)); // Only entry
      });
    });

    test('exit followed by reentry emits both crossings', () async {
      await service.addRegion(
        const Region(
          id: 'home',
          lat: 37.7749,
          lon: -122.4194,
          radius: 100,
          enabled: true,
          timestamp: 1704110400,
        ),
      );
      final events = <GeofenceTransition>[];
      final subscription = service.transitions.listen(events.add);
      await service.checkLocation(37.7749, -122.4194);
      await service.checkLocation(38, -122.5);
      await service.checkLocation(37.7749, -122.4194);
      await Future<void>.delayed(Duration.zero);
      expect(events.map((e) => e.event), [
        GeofenceEvent.exit,
        GeofenceEvent.enter,
      ]);
      await subscription.cancel();
    });

    test(
      'geofence diagnostics omit private region labels and coordinates',
      () async {
        final messages = <String>[];
        void capture(LogEvent event) => messages.add(event.message.toString());
        Logger.addLogListener(capture);
        try {
          await service.addRegion(
            const Region(
              id: 'private-home',
              lat: 37.7749,
              lon: -122.4194,
              radius: 100,
              enabled: true,
              timestamp: 1704110400,
              description: 'private-home',
            ),
          );
          await service.checkLocation(38, -122.5);
          await service.checkLocation(37.7749, -122.4194);
          expect(messages, isNotEmpty);
          expect(messages.join(), isNot(contains('private-home')));
          expect(messages.join(), isNot(contains('37.7749')));
        } finally {
          Logger.removeLogListener(capture);
        }
      },
    );

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

        await service.checkLocation(38.0, -122.5);

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
