import 'dart:convert';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:owntrack/bootstrap.dart';
import 'package:owntrack/data/datasources/outbox/outbox_store_native.dart';
import 'package:owntrack/data/services/secrets/secret_store.dart';
import 'package:owntrack/data/services/http_service.dart';
import 'package:owntrack/data/services/location_service.dart';
import 'package:owntrack/data/services/tracking_publication_policy.dart';
import 'package:owntrack/data/models/location_update.dart';
import 'package:owntrack/domain/providers/app_providers.dart';

class MockDio extends Mock implements Dio {}

class MockLocationService extends Mock implements LocationService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    registerFallbackValue(Options());
    registerFallbackValue(CancelToken());
  });
  test(
    'running tracking provider applies saved policy through durable HTTP delivery',
    () async {
      SharedPreferences.setMockInitialValues({});
      final dependencies = await initializeApplication(
        openSecrets: () async => SessionSecretStore(),
        outboxStore: SqliteOutboxStore(NativeDatabase.memory()),
      );
      await dependencies.settings.setConnectionMode('http');
      await dependencies.settings.setMonitoringMode(2);
      await dependencies.settings.setHttpUrl('https://example.com/pub');
      final fixes = StreamController<LocationUpdate>();
      final source = MockLocationService();
      when(() => source.locationUpdates).thenAnswer((_) => fixes.stream);
      when(source.startTracking).thenAnswer((_) async => true);
      when(source.stopTracking).thenAnswer((_) async {});
      final dio = MockDio();
      final sent = <Map<String, dynamic>>[];
      when(
        () => dio.post<Object?>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((call) async {
        sent.add(
          jsonDecode(call.namedArguments[#data] as String)
              as Map<String, dynamic>,
        );
        return Response(
          requestOptions: RequestOptions(path: '/pub'),
          statusCode: 200,
          data: '[]',
        );
      });
      var elapsed = Duration.zero;
      final container = ProviderContainer(
        overrides: [
          settingsLocalDataSourceProvider.overrideWithValue(
            dependencies.dataSource,
          ),
          settingsRepositoryProvider.overrideWithValue(dependencies.settings),
          messageQueueRepositoryProvider.overrideWithValue(dependencies.queue),
          locationServiceProvider.overrideWithValue(source),
          trackingClockProvider.overrideWithValue(() => elapsed),
          httpServiceProvider.overrideWith((ref) {
            final service = HttpService(
              dependencies.settings,
              ref.watch(endpointStateRepositoryProvider),
              dio: dio,
            );
            ref.onDispose(service.dispose);
            return service;
          }),
        ],
      );
      final tracking = container.read(trackingServiceProvider);
      final processor = container.read(messageProcessorProvider);
      try {
        expect(await tracking.startTracking(), isTrue);
        Future<void> sendFix(double latitude) async {
          final accepted = dependencies.queue.changes
              .firstWhere((count) => count > 0)
              .timeout(const Duration(seconds: 2));
          fixes.add(
            LocationUpdate(
              latitude: latitude,
              longitude: 0,
              accuracy: 1,
              timestamp: DateTime.now(),
            ),
          );
          await accepted;
          await processor.retryDelivery();
        }

        await sendFix(0);
        await dependencies.settings.setPublicationPolicy(
          TrackingPublicationPolicy(
            minimumInterval: const Duration(seconds: 5),
            minimumDistanceMeters: 1,
          ),
        );
        elapsed = const Duration(seconds: 10);
        await sendFix(0.00002);
        expect(sent.map((message) => message['lat']), [0, 0.00002]);
        expect(dependencies.queue.isEmpty, isTrue);
      } finally {
        await tracking.stopTracking();
        await processor.stop();
        container.dispose();
        await fixes.close();
        await dependencies.queue.close();
      }
    },
  );
  test(
    'application providers deliver queued message and route a POST response into contacts',
    () async {
      SharedPreferences.setMockInitialValues({});
      final dependencies = await initializeApplication(
        openSecrets: () async => SessionSecretStore(),
        outboxStore: SqliteOutboxStore(NativeDatabase.memory()),
      );
      await dependencies.settings.setConnectionMode('http');
      await dependencies.settings.setHttpUrl('https://example.com/pub');
      final dio = MockDio();
      when(
        () => dio.post<Object?>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/pub'),
          statusCode: 200,
          data: jsonEncode([
            {
              '_type': 'location',
              'topic': 'owntracks/alice/phone',
              'lat': 12,
              'lon': 34,
              'tst': 100,
            },
            {
              '_type': 'location',
              'topic': 'owntracks/invalid/phone',
              'lat': 999,
              'lon': 34,
              'tst': 100,
            },
          ]),
        ),
      );
      final container = ProviderContainer(
        overrides: [
          settingsLocalDataSourceProvider.overrideWithValue(
            dependencies.dataSource,
          ),
          settingsRepositoryProvider.overrideWithValue(dependencies.settings),
          messageQueueRepositoryProvider.overrideWithValue(dependencies.queue),
          httpServiceProvider.overrideWith((ref) {
            final service = HttpService(
              dependencies.settings,
              ref.watch(endpointStateRepositoryProvider),
              dio: dio,
            );
            ref.onDispose(service.dispose);
            return service;
          }),
        ],
      );
      await container.read(applicationRuntimeProvider.future);
      final processor = container.read(messageProcessorProvider);
      await processor.sendMessage({
        '_type': 'location',
        'lat': 1,
        'lon': 2,
        'tst': 100,
      });
      await processor.start();
      await Future<void>.delayed(Duration.zero);
      expect(dependencies.queue.size, 0);
      final contacts = container
          .read(contactsRepositoryProvider)
          .getAllContacts();
      expect(contacts.length, 1);
      expect(contacts.single.topic, 'owntracks/alice/phone');
      expect(contacts.single.lat, 12);
      await processor.stop();
      container.dispose();
      await dependencies.queue.close();
    },
  );
}
