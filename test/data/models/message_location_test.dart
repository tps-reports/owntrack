import 'package:flutter_test/flutter_test.dart';
import 'package:owntrack/data/models/message/message_location.dart';

void main() {
  group('MessageLocation', () {
    test('should create MessageLocation from JSON', () {
      final json = {
        'lat': 37.7749,
        'lon': -122.4194,
        'tst': 1704110400,
        'acc': 10,
        'alt': 100,
        'batt': 85,
        'vel': 5.5,
        'tid': 'AB',
      };

      final message = MessageLocation.fromJson(json);

      expect(message.lat, equals(37.7749));
      expect(message.lon, equals(-122.4194));
      expect(message.tst, equals(1704110400));
      expect(message.acc, equals(10));
      expect(message.alt, equals(100));
      expect(message.batt, equals(85));
      expect(message.vel, equals(5.5));
      expect(message.tid, equals('AB'));
    });

    test('should convert MessageLocation to JSON', () {
      const message = MessageLocation(
        lat: 37.7749,
        lon: -122.4194,
        tst: 1704110400,
        acc: 10,
        batt: 85,
        tid: 'AB',
      );

      final json = message.toJson();

      expect(json['_type'], equals('location'));
      expect(json['lat'], equals(37.7749));
      expect(json['lon'], equals(-122.4194));
      expect(json['tst'], equals(1704110400));
      expect(json['acc'], equals(10));
      expect(json['batt'], equals(85));
      expect(json['tid'], equals('AB'));
    });

    test('should use default values for optional fields', () {
      const message = MessageLocation(
        lat: 37.7749,
        lon: -122.4194,
        tst: 1704110400,
      );

      expect(message.acc, equals(0));
      expect(message.alt, equals(0));
      expect(message.batt, equals(0));
      expect(message.vel, equals(0));
      expect(message.tid, equals(''));
    });

    test('copyWith should update specified fields', () {
      const message = MessageLocation(
        lat: 37.7749,
        lon: -122.4194,
        tst: 1704110400,
        batt: 85,
      );

      final updated = message.copyWith(
        batt: 90,
        tid: 'XY',
      );

      expect(updated.lat, equals(37.7749));
      expect(updated.batt, equals(90));
      expect(updated.tid, equals('XY'));
    });

    test('equality should work correctly', () {
      const message1 = MessageLocation(
        lat: 37.7749,
        lon: -122.4194,
        tst: 1704110400,
      );

      const message2 = MessageLocation(
        lat: 37.7749,
        lon: -122.4194,
        tst: 1704110400,
        batt: 85,
      );

      const message3 = MessageLocation(
        lat: 38.0000,
        lon: -122.4194,
        tst: 1704110400,
      );

      expect(message1, equals(message2));
      expect(message1, isNot(equals(message3)));
    });
  });
}
