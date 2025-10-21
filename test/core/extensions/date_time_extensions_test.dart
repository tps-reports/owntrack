import 'package:flutter_test/flutter_test.dart';
import 'package:owntrack/core/extensions/date_time_extensions.dart';

void main() {
  group('DateTimeExtensions', () {
    test('toTimestamp converts DateTime to Unix timestamp', () {
      final dateTime = DateTime(2024, 1, 1, 12, 0, 0);
      final timestamp = dateTime.toTimestamp();
      expect(timestamp, isA<int>());
      expect(timestamp, greaterThan(0));
    });

    test('toIso8601 returns ISO 8601 formatted string', () {
      final dateTime = DateTime(2024, 1, 1, 12, 0, 0);
      final iso = dateTime.toIso8601();
      expect(iso, contains('2024-01-01'));
    });

    test('toRelative returns "Just now" for recent times', () {
      final now = DateTime.now();
      final relative = now.toRelative();
      expect(relative, equals('Just now'));
    });

    test('toRelative returns correct format for minutes ago', () {
      final fiveMinutesAgo = DateTime.now().subtract(const Duration(minutes: 5));
      final relative = fiveMinutesAgo.toRelative();
      expect(relative, contains('minutes ago'));
    });
  });

  group('TimestampExtensions', () {
    test('toDateTime converts Unix timestamp to DateTime', () {
      const timestamp = 1704110400; // 2024-01-01 12:00:00 UTC
      final dateTime = timestamp.toDateTime();
      expect(dateTime, isA<DateTime>());
      expect(dateTime.year, equals(2024));
    });
  });
}
