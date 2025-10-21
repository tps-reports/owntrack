import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:owntrack/data/datasources/local/preferences/settings_local_datasource.dart';
import 'package:owntrack/data/repositories/endpoint_state_repository.dart';
import 'package:owntrack/data/repositories/settings_repository.dart';
import 'package:owntrack/data/services/http_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockDio extends Mock implements Dio {}

class FakeRequestOptions extends Fake implements RequestOptions {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeRequestOptions());
    registerFallbackValue(Options());
  });

  group('HttpService', () {
    late HttpService service;
    late SettingsRepository settingsRepository;
    late EndpointStateRepository stateRepository;
    late MockDio mockDio;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final dataSource = SettingsLocalDataSource(prefs);
      settingsRepository = SettingsRepository(dataSource);
      stateRepository = EndpointStateRepository();
      mockDio = MockDio();

      service = HttpService(
        settingsRepository,
        stateRepository,
        dio: mockDio,
      );
    });

    tearDown(() {
      service.dispose();
      stateRepository.dispose();
    });

    group('connect', () {
      test('should fail when HTTP URL not configured', () async {
        final result = await service.connect();

        expect(result, isFalse);
        expect(stateRepository.state, equals(EndpointState.idle));
        expect(service.isConnected, isFalse);
      });

      test('should connect successfully when endpoint is reachable', () async {
        await settingsRepository.setHttpUrl('https://example.com/owntracks');

        when(() => mockDio.get(
              any(),
              options: any(named: 'options'),
            )).thenAnswer((_) async => Response(
              requestOptions: FakeRequestOptions(),
              statusCode: 200,
              data: {},
            ));

        final result = await service.connect();

        expect(result, isTrue);
        expect(stateRepository.state, equals(EndpointState.connected));
        expect(service.isConnected, isTrue);
      });

      test('should fail when endpoint is not reachable', () async {
        await settingsRepository.setHttpUrl('https://example.com/owntracks');

        when(() => mockDio.get(
              any(),
              options: any(named: 'options'),
            )).thenThrow(DioException(
              requestOptions: FakeRequestOptions(),
              error: 'Connection refused',
            ));

        final result = await service.connect();

        expect(result, isFalse);
        expect(stateRepository.state, equals(EndpointState.idle));
        expect(service.isConnected, isFalse);
      });
    });

    group('disconnect', () {
      test('should disconnect and update state', () async {
        await settingsRepository.setHttpUrl('https://example.com/owntracks');

        when(() => mockDio.get(
              any(),
              options: any(named: 'options'),
            )).thenAnswer((_) async => Response(
              requestOptions: FakeRequestOptions(),
              statusCode: 200,
            ));

        await service.connect();
        expect(service.isConnected, isTrue);

        await service.disconnect();

        expect(service.isConnected, isFalse);
        expect(stateRepository.state, equals(EndpointState.disconnected));
      });
    });

    group('publish', () {
      test('should fail when not connected', () async {
        final result = await service.publish('{"test": "data"}');
        expect(result, isFalse);
      });

      test('should publish successfully via HTTP POST', () async {
        await settingsRepository.setHttpUrl('https://example.com/owntracks');

        when(() => mockDio.get(
              any(),
              options: any(named: 'options'),
            )).thenAnswer((_) async => Response(
              requestOptions: FakeRequestOptions(),
              statusCode: 200,
            ));

        when(() => mockDio.post(
              any(),
              data: any(named: 'data'),
              options: any(named: 'options'),
            )).thenAnswer((_) async => Response(
              requestOptions: FakeRequestOptions(),
              statusCode: 200,
            ));

        await service.connect();
        final result = await service.publish('{"test": "data"}');

        expect(result, isTrue);
        verify(() => mockDio.post(
              'https://example.com/owntracks',
              data: '{"test": "data"}',
              options: any(named: 'options'),
            )).called(1);
      });

      test('should fail when HTTP POST returns error status', () async {
        await settingsRepository.setHttpUrl('https://example.com/owntracks');

        when(() => mockDio.get(
              any(),
              options: any(named: 'options'),
            )).thenAnswer((_) async => Response(
              requestOptions: FakeRequestOptions(),
              statusCode: 200,
            ));

        when(() => mockDio.post(
              any(),
              data: any(named: 'data'),
              options: any(named: 'options'),
            )).thenAnswer((_) async => Response(
              requestOptions: FakeRequestOptions(),
              statusCode: 500,
            ));

        await service.connect();
        final result = await service.publish('{"test": "data"}');

        expect(result, isFalse);
      });

      test('should fail when HTTP POST throws exception', () async {
        await settingsRepository.setHttpUrl('https://example.com/owntracks');

        when(() => mockDio.get(
              any(),
              options: any(named: 'options'),
            )).thenAnswer((_) async => Response(
              requestOptions: FakeRequestOptions(),
              statusCode: 200,
            ));

        when(() => mockDio.post(
              any(),
              data: any(named: 'data'),
              options: any(named: 'options'),
            )).thenThrow(DioException(
              requestOptions: FakeRequestOptions(),
              error: 'Network error',
            ));

        await service.connect();
        final result = await service.publish('{"test": "data"}');

        expect(result, isFalse);
      });
    });

    group('messages stream', () {
      test('should receive messages via polling', () async {
        await settingsRepository.setHttpUrl('https://example.com/owntracks');

        when(() => mockDio.get(
              any(),
              options: any(named: 'options'),
            )).thenAnswer((_) async => Response(
              requestOptions: FakeRequestOptions(),
              statusCode: 200,
              data: {'_type': 'location', 'lat': 37.7749, 'lon': -122.4194},
            ));

        final messages = <Map<String, dynamic>>[];
        service.messages.listen(messages.add);

        await service.connect();

        // Wait for initial poll
        await Future.delayed(const Duration(milliseconds: 100));

        expect(messages.length, greaterThan(0));
        expect(messages.first['_type'], equals('location'));
      });

      test('should handle array of messages from polling', () async {
        await settingsRepository.setHttpUrl('https://example.com/owntracks');

        when(() => mockDio.get(
              any(),
              options: any(named: 'options'),
            )).thenAnswer((_) async => Response(
              requestOptions: FakeRequestOptions(),
              statusCode: 200,
              data: [
                {'_type': 'location', 'lat': 37.7749},
                {'_type': 'location', 'lat': 38.0000},
              ],
            ));

        final messages = <Map<String, dynamic>>[];
        service.messages.listen(messages.add);

        await service.connect();

        // Wait for initial poll
        await Future.delayed(const Duration(milliseconds: 100));

        expect(messages.length, equals(2));
        expect(messages[0]['lat'], equals(37.7749));
        expect(messages[1]['lat'], equals(38.0000));
      });
    });
  });
}
