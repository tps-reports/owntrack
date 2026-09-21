import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:owntrack/data/datasources/local/preferences/settings_local_datasource.dart';
import 'package:owntrack/data/repositories/endpoint_state_repository.dart';
import 'package:owntrack/data/repositories/settings_repository.dart';
import 'package:owntrack/data/services/http_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockDio extends Mock implements Dio {}

void main() {
  setUpAll(() {
    registerFallbackValue(Options());
    registerFallbackValue(CancelToken());
  });
  late MockDio dio;
  late SettingsRepository settings;
  late EndpointStateRepository state;
  late HttpService service;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settings = SettingsRepository(
      SettingsLocalDataSource(await SharedPreferences.getInstance()),
    );
    await settings.setHttpUrl('https://example.com/pub');
    await settings.setDeviceId('phone');
    state = EndpointStateRepository();
    dio = MockDio();
    service = HttpService(settings, state, dio: dio);
  });
  tearDown(() {
    service.dispose();
    state.dispose();
  });
  void respond(int status, Object? data) {
    when(
      () => dio.post<Object?>(
        any(),
        data: any(named: 'data'),
        options: any(named: 'options'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer(
      (_) async => Response<Object?>(
        requestOptions: RequestOptions(path: '/pub'),
        statusCode: status,
        data: data,
      ),
    );
  }

  test(
    'configuration makes POST-only endpoint ready without a GET or false connected status',
    () async {
      expect(await service.connect(), isTrue);
      expect(service.isConnected, isTrue);
      expect(state.state, EndpointState.idle);
      verifyNever(() => dio.get(any(), options: any(named: 'options')));
    },
  );
  test('missing endpoint has actionable error', () async {
    await settings.setHttpUrl('');
    expect(await service.connect(), isFalse);
    expect(state.state, EndpointState.error);
  });
  test('insecure endpoint is rejected', () async {
    await settings.setHttpUrl('http://example.com/pub');
    expect(await service.connect(), isFalse);
    expect(state.errorMessage, contains('HTTPS'));
  });
  for (final status in [200, 201, 202, 204, 299]) {
    test('HTTP $status acknowledges outgoing delivery', () async {
      respond(status, '');
      await service.connect();
      expect(await service.publish('{"_type":"location"}'), isTrue);
      expect(state.state, EndpointState.connected);
    });
  }
  test('response location messages are emitted from POST', () async {
    respond(
      200,
      '[{"_type":"location","topic":"owntracks/alice/phone","lat":12,"lon":34,"tst":10}]',
    );
    final incoming = service.messages.first;
    await service.connect();
    expect(await service.publish('{}'), isTrue);
    expect((await incoming)['topic'], 'owntracks/alice/phone');
  });
  test(
    'malformed response surfaces error without retrying accepted outgoing delivery',
    () async {
      respond(200, '["invalid"]');
      await service.connect();
      expect(await service.publish('{}'), isTrue);
      expect(state.state, EndpointState.error);
      expect(state.errorMessage, contains('response'));
    },
  );
  test(
    'credentials go in auth header, never URL, and device identity is supplied',
    () async {
      await settings.setHttpUrl('https://alice:secret@example.com/pub');
      respond(204, '');
      await service.connect();
      expect(await service.publish('{}'), isTrue);
      final options =
          verify(
                () => dio.post<Object?>(
                  'https://example.com/pub',
                  data: '{}',
                  options: captureAny(named: 'options'),
                  cancelToken: any(named: 'cancelToken'),
                ),
              ).captured.single
              as Options;
      expect(options.headers!['Authorization'], 'Basic YWxpY2U6c2VjcmV0');
      expect(options.headers!['X-Limit-D'], 'phone');
      expect(options.headers!['X-Limit-U'], 'alice');
      expect(options.followRedirects, isFalse);
    },
  );
  test('failed POST remains unacknowledged with actionable status', () async {
    respond(401, '');
    await service.connect();
    expect(await service.publish('{}'), isFalse);
    expect(state.state, EndpointState.error);
  });
  test('disconnect prevents requests', () async {
    await service.connect();
    await service.disconnect();
    expect(await service.publish('{}'), isFalse);
    expect(state.state, EndpointState.disconnected);
    verifyNever(
      () => dio.post<Object?>(
        any(),
        data: any(named: 'data'),
        options: any(named: 'options'),
        cancelToken: any(named: 'cancelToken'),
      ),
    );
  });
}
