import 'package:flutter_test/flutter_test.dart';
import 'package:owntrack/data/models/friend.dart';

void main() {
  group('Friend', () {
    test('should create Friend from JSON', () {
      final json = {
        'id': 'friend1',
        'topic': 'owntracks/user/device',
        'name': 'John Doe',
        'lat': 37.7749,
        'lon': -122.4194,
        'timestamp': 1704110400,
        'battery': 85,
      };

      final friend = Friend.fromJson(json);

      expect(friend.id, equals('friend1'));
      expect(friend.topic, equals('owntracks/user/device'));
      expect(friend.name, equals('John Doe'));
      expect(friend.lat, equals(37.7749));
      expect(friend.lon, equals(-122.4194));
      expect(friend.timestamp, equals(1704110400));
      expect(friend.battery, equals(85));
    });

    test('should convert Friend to JSON', () {
      const friend = Friend(
        id: 'friend1',
        topic: 'owntracks/user/device',
        name: 'John Doe',
        lat: 37.7749,
        lon: -122.4194,
        timestamp: 1704110400,
        battery: 85,
      );

      final json = friend.toJson();

      expect(json['id'], equals('friend1'));
      expect(json['topic'], equals('owntracks/user/device'));
      expect(json['name'], equals('John Doe'));
      expect(json['lat'], equals(37.7749));
      expect(json['lon'], equals(-122.4194));
      expect(json['timestamp'], equals(1704110400));
      expect(json['battery'], equals(85));
    });

    test('displayName should return name if available', () {
      const friend = Friend(
        id: 'friend1',
        topic: 'owntracks/user/device',
        name: 'John Doe',
      );

      expect(friend.displayName, equals('John Doe'));
    });

    test('displayName should fallback to topic device name', () {
      const friend = Friend(
        id: 'friend1',
        topic: 'owntracks/user/device',
      );

      expect(friend.displayName, equals('device'));
    });

    test('hasLocation should return true when lat/lon available', () {
      const friend = Friend(
        id: 'friend1',
        topic: 'owntracks/user/device',
        lat: 37.7749,
        lon: -122.4194,
      );

      expect(friend.hasLocation, isTrue);
    });

    test('hasLocation should return false when lat/lon missing', () {
      const friend = Friend(
        id: 'friend1',
        topic: 'owntracks/user/device',
      );

      expect(friend.hasLocation, isFalse);
    });

    test('batteryPercentage should format correctly', () {
      const friend = Friend(
        id: 'friend1',
        topic: 'owntracks/user/device',
        battery: 85,
      );

      expect(friend.batteryPercentage, equals('85%'));
    });

    test('batteryPercentage should show Unknown when not available', () {
      const friend = Friend(
        id: 'friend1',
        topic: 'owntracks/user/device',
      );

      expect(friend.batteryPercentage, equals('Unknown'));
    });

    test('copyWith should update specified fields', () {
      const friend = Friend(
        id: 'friend1',
        topic: 'owntracks/user/device',
        name: 'John Doe',
        battery: 85,
      );

      final updated = friend.copyWith(
        name: 'Jane Doe',
        battery: 90,
      );

      expect(updated.id, equals('friend1'));
      expect(updated.name, equals('Jane Doe'));
      expect(updated.battery, equals(90));
    });

    test('equality should work correctly', () {
      const friend1 = Friend(
        id: 'friend1',
        topic: 'owntracks/user/device',
      );

      const friend2 = Friend(
        id: 'friend1',
        topic: 'owntracks/another/device',
      );

      const friend3 = Friend(
        id: 'friend2',
        topic: 'owntracks/user/device',
      );

      expect(friend1, equals(friend2));
      expect(friend1, isNot(equals(friend3)));
    });
  });
}
