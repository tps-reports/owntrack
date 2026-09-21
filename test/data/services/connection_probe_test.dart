import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:owntrack/data/services/connection_probe.dart';

class MockDio extends Mock implements Dio {}

void main() {
  setUpAll(() => registerFallbackValue(Options()));
  test(
    'HTTP probe uses POST without publishing location or URL credentials',
    () async {
      final dio = MockDio();
      when(
        () => dio.post<Object?>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response<Object?>(
          requestOptions: RequestOptions(path: '/pub'),
          statusCode: 204,
        ),
      );
      final probe = ConnectionProbe(dio: dio);
      await probe.testHttp('https://user:secret@example.com/pub');
      final call =
          verify(
                () => dio.post<Object?>(
                  'https://example.com/pub',
                  data: '',
                  options: captureAny(named: 'options'),
                ),
              ).captured.single
              as Options;
      expect(call.headers!['Authorization'], 'Basic dXNlcjpzZWNyZXQ=');
      probe.dispose();
    },
  );
  test('HTTP probe rejects insecure URLs before sending credentials', () async {
    final dio = MockDio();
    final probe = ConnectionProbe(dio: dio);
    await expectLater(
      probe.testHttp('http://user:secret@example.com/pub'),
      throwsA(isA<ArgumentError>()),
    );
    verifyNever(
      () => dio.post<Object?>(
        any(),
        data: any(named: 'data'),
        options: any(named: 'options'),
      ),
    );
    probe.dispose();
  });
  test('HTTP probe rejects unsuccessful responses', () async {
    final dio = MockDio();
    when(
      () => dio.post<Object?>(
        any(),
        data: any(named: 'data'),
        options: any(named: 'options'),
      ),
    ).thenAnswer(
      (_) async => Response<Object?>(
        requestOptions: RequestOptions(path: '/pub'),
        statusCode: 401,
      ),
    );
    final probe = ConnectionProbe(dio: dio);
    await expectLater(
      probe.testHttp('https://example.com/pub'),
      throwsA(isA<StateError>()),
    );
    probe.dispose();
  });
}
