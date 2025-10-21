import 'package:flutter_test/flutter_test.dart';
import 'package:owntrack/core/errors/failures.dart';

void main() {
  group('Failures', () {
    test('NetworkFailure should have correct message', () {
      const failure = NetworkFailure('No internet connection');
      expect(failure.message, equals('No internet connection'));
      expect(failure.exception, isNull);
    });

    test('NetworkFailure with exception should store exception', () {
      final exception = Exception('Test exception');
      final failure = NetworkFailure('Network error', exception);
      expect(failure.message, equals('Network error'));
      expect(failure.exception, equals(exception));
    });

    test('DatabaseFailure should have correct message', () {
      const failure = DatabaseFailure('Database error');
      expect(failure.message, equals('Database error'));
    });

    test('LocationFailure should have correct message', () {
      const failure = LocationFailure('Location not available');
      expect(failure.message, equals('Location not available'));
    });

    test('PermissionFailure should have correct message', () {
      const failure = PermissionFailure('Permission denied');
      expect(failure.message, equals('Permission denied'));
    });

    test('MqttFailure should have correct message', () {
      const failure = MqttFailure('MQTT connection failed');
      expect(failure.message, equals('MQTT connection failed'));
    });

    test('HttpFailure should have correct message', () {
      const failure = HttpFailure('HTTP request failed');
      expect(failure.message, equals('HTTP request failed'));
    });

    test('Failures with same message should be equal', () {
      const failure1 = NetworkFailure('Test');
      const failure2 = NetworkFailure('Test');
      expect(failure1, equals(failure2));
    });

    test('Failures with different messages should not be equal', () {
      const failure1 = NetworkFailure('Test1');
      const failure2 = NetworkFailure('Test2');
      expect(failure1, isNot(equals(failure2)));
    });
  });
}
