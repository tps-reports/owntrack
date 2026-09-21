import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:owntrack/data/datasources/local/preferences/settings_local_datasource.dart';
import 'package:owntrack/data/models/location_update.dart';
import 'package:owntrack/data/models/region.dart';
import 'package:owntrack/data/repositories/settings_repository.dart';
import 'package:owntrack/data/repositories/regions_repository.dart';
import 'package:owntrack/data/services/battery_service.dart';
import 'package:owntrack/data/services/geofencing_service.dart';
import 'package:owntrack/data/services/location_service.dart';
import 'package:owntrack/data/services/message_processor.dart';
import 'package:owntrack/data/services/tracking_publication_policy.dart';
import 'package:owntrack/data/services/tracking_service.dart';
import 'package:owntrack/core/constants/app_constants.dart';

class MockLocation extends Mock implements LocationService {}

class MockProcessor extends Mock implements MessageProcessor {}

void main() {
  late MockLocation location;
  late MockProcessor processor;
  late TrackingService tracking;
  late BatteryService battery;
  late GeofencingService geofencing;
  late StreamController<LocationUpdate> updates;
  late SettingsRepository settings;
  late DateTime now;
  late Duration elapsed;
  late TrackingPublicationPolicy policy;
  LocationUpdate fix({
    DateTime? timestamp,
    double latitude = 1,
    double accuracy = 10,
    bool isMocked = false,
    double? altitude,
    double? speed,
    double? heading,
  }) => LocationUpdate(
    latitude: latitude,
    longitude: 2,
    accuracy: accuracy,
    timestamp: timestamp ?? now,
    isMocked: isMocked,
    altitude: altitude,
    speed: speed,
    heading: heading,
  );
  void advance(Duration duration) {
    elapsed += duration;
    now = now.add(duration);
  }

  Future<void> emit(LocationUpdate value) async {
    updates.add(value);
    await pumpEventQueue();
  }

  setUp(() async {
    now = DateTime.utc(2026, 9, 20);
    elapsed = Duration.zero;
    policy = TrackingPublicationPolicy();
    SharedPreferences.setMockInitialValues({});
    final source = SettingsLocalDataSource(
      await SharedPreferences.getInstance(),
    );
    location = MockLocation();
    processor = MockProcessor();
    battery = BatteryService();
    geofencing = GeofencingService(RegionsRepository(source));
    settings = SettingsRepository(source);
    updates = StreamController<LocationUpdate>.broadcast();
    when(() => location.locationUpdates).thenAnswer((_) => updates.stream);
    when(() => location.startTracking()).thenAnswer((_) async => true);
    when(() => location.stopTracking()).thenAnswer((_) async {});
    when(
      () => processor.sendMessage(any(), topic: any(named: 'topic')),
    ).thenAnswer((_) async {});
    tracking = TrackingService(
      location,
      geofencing,
      processor,
      settings,
      battery,
      now: () => now,
      monotonicNow: () => elapsed,
      publicationPolicy: () => policy,
    );
  });
  tearDown(() {
    tracking.dispose();
    updates.close();
    battery.dispose();
    geofencing.dispose();
  });
  test('concurrent manual requests acquire and enqueue only once', () async {
    final acquired = Completer<LocationUpdate?>();
    when(
      () => location.getCurrentLocation(),
    ).thenAnswer((_) => acquired.future);
    final first = tracking.publishCurrentLocation();
    final second = tracking.publishCurrentLocation();
    acquired.complete(fix());
    await Future.wait([first, second]);
    verify(() => location.getCurrentLocation()).called(1);
    verify(
      () => processor.sendMessage(any(), topic: any(named: 'topic')),
    ).called(1);
  });
  test(
    'stopping during manual acquisition prevents late publication',
    () async {
      final acquired = Completer<LocationUpdate?>();
      when(
        () => location.getCurrentLocation(),
      ).thenAnswer((_) => acquired.future);
      final pending = tracking.publishCurrentLocation();
      final rejected = expectLater(pending, throwsStateError);
      await tracking.stopTracking();
      acquired.complete(fix());
      await rejected;
      verifyNever(
        () => processor.sendMessage(any(), topic: any(named: 'topic')),
      );
    },
  );
  test('stale manual fix is rejected without queueing', () async {
    when(() => location.getCurrentLocation()).thenAnswer(
      (_) async => fix(timestamp: now.subtract(const Duration(hours: 1))),
    );
    await expectLater(tracking.publishCurrentLocation(), throwsStateError);
    verifyNever(() => processor.sendMessage(any(), topic: any(named: 'topic')));
  });

  test(
    'unknown optional telemetry is omitted instead of inventing zeroes',
    () async {
      when(() => location.getCurrentLocation()).thenAnswer((_) async => fix());
      await tracking.publishCurrentLocation();
      final message =
          verify(
                () => processor.sendMessage(
                  captureAny(),
                  topic: any(named: 'topic'),
                ),
              ).captured.single
              as Map;
      expect(message.containsKey('alt'), isFalse);
      expect(message.containsKey('vel'), isFalse);
      expect(message.containsKey('cog'), isFalse);
    },
  );

  test(
    'nonfinite optional telemetry cannot discard a valid location',
    () async {
      when(() => location.getCurrentLocation()).thenAnswer(
        (_) async =>
            fix(altitude: double.nan, speed: double.infinity, heading: -1),
      );
      await tracking.publishCurrentLocation();
      final message =
          verify(
                () => processor.sendMessage(
                  captureAny(),
                  topic: any(named: 'topic'),
                ),
              ).captured.single
              as Map;
      expect(message['lat'], 1);
      expect(message.containsKey('alt'), isFalse);
      expect(message.containsKey('vel'), isFalse);
      expect(message.containsKey('cog'), isFalse);
    },
  );

  test('measured optional telemetry retains protocol units', () async {
    when(
      () => location.getCurrentLocation(),
    ).thenAnswer((_) async => fix(altitude: -12.3, speed: 10, heading: 359.9));
    await tracking.publishCurrentLocation();
    final message =
        verify(
              () => processor.sendMessage(
                captureAny(),
                topic: any(named: 'topic'),
              ),
            ).captured.single
            as Map;
    expect(message['alt'], -12);
    expect(message['vel'], 36);
    expect(message['cog'], 359);
  });

  test(
    'restarting publishes a new first fix without the old interval gate',
    () async {
      await tracking.startTracking();
      updates.add(fix());
      await pumpEventQueue();
      await tracking.stopTracking();
      await tracking.startTracking();
      updates.add(fix());
      await pumpEventQueue();

      verify(
        () => processor.sendMessage(any(), topic: any(named: 'topic')),
      ).called(2);
    },
  );

  test('movement requires minimum time and minimum distance', () async {
    await tracking.startTracking();
    await emit(fix());
    advance(const Duration(seconds: 29));
    await emit(fix(latitude: 1.001));
    advance(const Duration(seconds: 1));
    await emit(fix(latitude: 1.0001));
    await emit(fix(latitude: 1.001));
    final messages = verify(
      () => processor.sendMessage(captureAny(), topic: any(named: 'topic')),
    ).captured;
    expect(messages.map((message) => (message as Map)['lat']), [1, 1.001]);
  });

  test('a fresh stationary fix queues at the heartbeat boundary', () async {
    await tracking.startTracking();
    await emit(fix());
    advance(const Duration(seconds: 299));
    await emit(fix());
    advance(const Duration(seconds: 1));
    await emit(fix());
    final messages = verify(
      () => processor.sendMessage(captureAny(), topic: any(named: 'topic')),
    ).captured;
    expect(messages.length, 2);
    expect((messages.last as Map)['tst'], now.millisecondsSinceEpoch ~/ 1000);
  });

  test('wall clock corrections do not change publication scheduling', () async {
    await tracking.startTracking();
    await emit(fix());
    now = now.add(const Duration(days: 1));
    elapsed = const Duration(seconds: 29);
    await emit(fix(latitude: 1.001));
    now = now.subtract(const Duration(days: 2));
    elapsed = const Duration(seconds: 30);
    await emit(fix(latitude: 1.001));
    elapsed = const Duration(seconds: 330);
    await emit(fix(latitude: 1.001));
    verify(
      () => processor.sendMessage(any(), topic: any(named: 'topic')),
    ).called(3);
  });

  test('invalid automatic fixes cannot satisfy a due heartbeat', () async {
    await tracking.startTracking();
    await emit(fix());
    advance(const Duration(minutes: 5));
    await emit(fix(accuracy: 101));
    await emit(fix(isMocked: true));
    await emit(fix(latitude: 91));
    await emit(fix(timestamp: now.subtract(const Duration(minutes: 3))));
    expect(tracking.lastError, contains('Location fix rejected'));
    verify(
      () => processor.sendMessage(any(), topic: any(named: 'topic')),
    ).called(1);
    await emit(fix());
    verify(
      () => processor.sendMessage(any(), topic: any(named: 'topic')),
    ).called(1);
    expect(tracking.lastError, isNull);
  });

  test('failed queue acceptance leaves the next fix eligible', () async {
    var attempts = 0;
    when(
      () => processor.sendMessage(any(), topic: any(named: 'topic')),
    ).thenAnswer((_) async {
      if (attempts++ == 0) throw StateError('Outbox unavailable');
    });
    await tracking.startTracking();
    await emit(fix());
    expect(tracking.lastError, contains('Outbox unavailable'));
    advance(const Duration(seconds: 1));
    await emit(fix());
    expect(attempts, 2);
    expect(tracking.lastError, isNull);
  });

  test('changed policy is applied to the running stream', () async {
    await tracking.startTracking();
    await emit(fix());
    policy = TrackingPublicationPolicy(
      minimumInterval: const Duration(seconds: 10),
      minimumDistanceMeters: 10,
      heartbeatInterval: const Duration(seconds: 60),
    );
    advance(const Duration(seconds: 10));
    await emit(fix(latitude: 1.0002));
    verify(
      () => processor.sendMessage(any(), topic: any(named: 'topic')),
    ).called(2);
  });

  test('quiet and manual modes never publish stream events', () async {
    await tracking.startTracking();
    await settings.setMonitoringMode(AppConstants.monitoringModeQuiet);
    await emit(fix());
    await settings.setMonitoringMode(AppConstants.monitoringModeManual);
    advance(const Duration(minutes: 5));
    await emit(fix(latitude: 2));
    verifyNever(() => processor.sendMessage(any(), topic: any(named: 'topic')));
  });

  test('configured heading trigger is used by the running service', () async {
    policy = TrackingPublicationPolicy(minimumHeadingChangeDegrees: 30);
    await tracking.startTracking();
    await emit(fix(heading: 359, speed: 2));
    advance(const Duration(seconds: 30));
    await emit(fix(latitude: 1.0003, heading: 1, speed: 2));
    await emit(fix(latitude: 1.0003, heading: 40, speed: 2));
    final messages = verify(
      () => processor.sendMessage(captureAny(), topic: any(named: 'topic')),
    ).captured;
    expect(messages.map((message) => (message as Map)['cog']), [359, 40]);
  });

  test('stop cancels a pending start before reporting success', () async {
    final started = Completer<bool>();
    when(() => location.startTracking()).thenAnswer((_) => started.future);
    final start = tracking.startTracking();
    await pumpEventQueue();
    final stop = tracking.stopTracking();
    started.complete(true);
    expect(await start, isFalse);
    await stop;
    expect(tracking.isTracking, isFalse);
    await emit(fix());
    verifyNever(() => processor.sendMessage(any(), topic: any(named: 'topic')));
  });

  test('a start requested after stop waits for cleanup then starts', () async {
    await tracking.startTracking();
    await emit(fix());
    final stop = tracking.stopTracking();
    final start = tracking.startTracking();
    await stop;
    expect(await start, isTrue);
    await emit(fix());
    expect(tracking.isTracking, isTrue);
    verify(
      () => processor.sendMessage(any(), topic: any(named: 'topic')),
    ).called(2);
  });

  test(
    'failed geofence queue acceptance retries the original crossing',
    () async {
      await geofencing.addRegion(
        Region(
          id: 'home',
          lat: 1,
          lon: 2,
          radius: 100,
          timestamp: now.millisecondsSinceEpoch ~/ 1000,
        ),
      );
      final attemptedTransitions = <Map<String, dynamic>>[];
      final observedTransitions = <GeofenceTransition>[];
      final subscription = geofencing.transitions.listen(
        observedTransitions.add,
      );
      when(
        () => processor.sendMessage(any(), topic: any(named: 'topic')),
      ).thenAnswer((invocation) async {
        final message =
            invocation.positionalArguments.first as Map<String, dynamic>;
        if (message['_type'] == 'transition') {
          attemptedTransitions.add(message);
          if (attemptedTransitions.length == 1) {
            throw StateError('Outbox unavailable');
          }
        }
      });
      await tracking.startTracking();
      await emit(fix(latitude: 1.01));
      advance(const Duration(seconds: 1));
      final crossedAt = now.millisecondsSinceEpoch ~/ 1000;
      await emit(fix());
      expect(tracking.lastError, contains('Outbox unavailable'));
      advance(const Duration(seconds: 10));
      await emit(fix(latitude: 1.0001));

      expect(attemptedTransitions.length, 2);
      expect(attemptedTransitions.map((message) => message['tst']), [
        crossedAt,
        crossedAt,
      ]);
      expect(attemptedTransitions.map((message) => message['lat']), [1, 1]);
      expect(observedTransitions.length, 1);
      expect(geofencing.isInsideRegion('home'), isTrue);
      expect(tracking.lastError, isNull);
      await subscription.cancel();
    },
  );
}
