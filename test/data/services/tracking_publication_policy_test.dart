import 'package:flutter_test/flutter_test.dart';
import 'package:owntrack/data/models/location_update.dart';
import 'package:owntrack/data/services/tracking_publication_policy.dart';

void main() {
  final now = DateTime.utc(2026, 9, 20);
  LocationUpdate fix({
    double latitude = 40,
    double longitude = -105,
    double accuracy = 10,
    DateTime? timestamp,
    bool isMocked = false,
    double? heading,
    double? speed,
  }) => LocationUpdate(
    latitude: latitude,
    longitude: longitude,
    accuracy: accuracy,
    timestamp: timestamp ?? now,
    isMocked: isMocked,
    heading: heading,
    speed: speed,
  );

  test('movement requires both distance and elapsed interval', () {
    final policy = TrackingPublicationPolicy();
    final origin = fix();
    final moved = fix(latitude: 40.001);
    expect(
      policy.shouldPublish(
        moved,
        now: now,
        elapsedSincePublication: const Duration(seconds: 29),
        lastPublishedLocation: origin,
      ),
      isFalse,
    );
    expect(
      policy.shouldPublish(
        fix(latitude: 40.0001),
        now: now,
        elapsedSincePublication: const Duration(seconds: 30),
        lastPublishedLocation: origin,
      ),
      isFalse,
    );
    expect(
      policy.shouldPublish(
        moved,
        now: now,
        elapsedSincePublication: const Duration(seconds: 30),
        lastPublishedLocation: origin,
      ),
      isTrue,
    );
  });

  test('fresh stationary fixes publish at the heartbeat boundary', () {
    final policy = TrackingPublicationPolicy();
    final origin = fix(timestamp: now.subtract(const Duration(minutes: 5)));
    expect(
      policy.shouldPublish(
        fix(),
        now: now,
        elapsedSincePublication: const Duration(seconds: 299),
        lastPublishedLocation: origin,
      ),
      isFalse,
    );
    expect(
      policy.shouldPublish(
        fix(),
        now: now,
        elapsedSincePublication: const Duration(minutes: 5),
        lastPublishedLocation: origin,
      ),
      isTrue,
    );
  });

  test('quality gates also reject a first fix and a due heartbeat', () {
    final policy = TrackingPublicationPolicy();
    final invalidFixes = [
      fix(accuracy: 101),
      fix(accuracy: -1),
      fix(accuracy: double.nan),
      fix(isMocked: true),
      fix(latitude: 91),
      fix(longitude: -181),
      fix(latitude: double.infinity),
      fix(timestamp: now.subtract(const Duration(seconds: 121))),
      fix(timestamp: now.add(const Duration(seconds: 31))),
    ];
    for (final location in invalidFixes) {
      expect(policy.isAcceptable(location, now: now), isFalse);
      expect(
        policy.shouldPublish(
          location,
          now: now,
          elapsedSincePublication: Duration.zero,
        ),
        isFalse,
      );
      expect(
        policy.shouldPublish(
          location,
          now: now,
          elapsedSincePublication: const Duration(minutes: 5),
          lastPublishedLocation: fix(),
        ),
        isFalse,
      );
    }
  });

  test('quality threshold boundaries are accepted', () {
    final policy = TrackingPublicationPolicy();
    expect(
      policy.isAcceptable(
        fix(accuracy: 100, timestamp: now.subtract(const Duration(minutes: 2))),
        now: now,
      ),
      isTrue,
    );
    expect(
      policy.isAcceptable(
        fix(accuracy: 0, timestamp: now.add(const Duration(seconds: 30))),
        now: now,
      ),
      isTrue,
    );
  });

  test('configured thresholds change actual trajectory decisions', () {
    final policy = TrackingPublicationPolicy(
      minimumInterval: const Duration(seconds: 10),
      minimumDistanceMeters: 10,
      heartbeatInterval: const Duration(seconds: 60),
    );
    expect(
      policy.shouldPublish(
        fix(latitude: 40.0002),
        now: now,
        elapsedSincePublication: const Duration(seconds: 10),
        lastPublishedLocation: fix(),
      ),
      isTrue,
    );
    expect(
      policy.shouldPublish(
        fix(),
        now: now,
        elapsedSincePublication: const Duration(seconds: 60),
        lastPublishedLocation: fix(),
      ),
      isTrue,
    );
  });

  test('a backwards monotonic reading cannot bypass the interval gate', () {
    final policy = TrackingPublicationPolicy();
    expect(
      policy.shouldPublish(
        fix(latitude: 41),
        now: now,
        elapsedSincePublication: const Duration(seconds: -1),
        lastPublishedLocation: fix(),
      ),
      isFalse,
    );
  });

  test('heading uses the shortest angle across north', () {
    final policy = TrackingPublicationPolicy(minimumHeadingChangeDegrees: 30);
    final origin = fix(heading: 359, speed: 2);
    expect(
      policy.shouldPublish(
        fix(latitude: 40.0003, heading: 1, speed: 2),
        now: now,
        elapsedSincePublication: const Duration(seconds: 30),
        lastPublishedLocation: origin,
      ),
      isFalse,
    );
    expect(
      policy.shouldPublish(
        fix(latitude: 40.0003, heading: 40, speed: 2),
        now: now,
        elapsedSincePublication: const Duration(seconds: 30),
        lastPublishedLocation: origin,
      ),
      isTrue,
    );
  });

  test('heading obeys time, movement confidence, and valid bearing gates', () {
    final policy = TrackingPublicationPolicy(minimumHeadingChangeDegrees: 30);
    final origin = fix(heading: 0, speed: 2);
    for (final candidate in [
      fix(latitude: 40.00001, heading: 90, speed: 2),
      fix(latitude: 40.0003, accuracy: 40, heading: 90, speed: 2),
      fix(latitude: 40.0003, heading: 90, speed: 0),
      fix(latitude: 40.0003, heading: 90),
      fix(latitude: 40.0003, heading: double.nan, speed: 2),
      fix(latitude: 40.0003, heading: -1, speed: 2),
      fix(latitude: 40.0003, heading: 360, speed: 2),
    ]) {
      expect(
        policy.shouldPublish(
          candidate,
          now: now,
          elapsedSincePublication: const Duration(seconds: 30),
          lastPublishedLocation: origin,
        ),
        isFalse,
      );
    }
    expect(
      policy.shouldPublish(
        fix(latitude: 40.0003, heading: 90, speed: 2),
        now: now,
        elapsedSincePublication: const Duration(seconds: 29),
        lastPublishedLocation: origin,
      ),
      isFalse,
    );
  });

  test('heading publication is disabled by default', () {
    expect(
      TrackingPublicationPolicy().shouldPublish(
        fix(latitude: 40.0003, heading: 90, speed: 2),
        now: now,
        elapsedSincePublication: const Duration(seconds: 30),
        lastPublishedLocation: fix(heading: 0, speed: 2),
      ),
      isFalse,
    );
  });

  test('unsafe policy values are rejected at construction', () {
    expect(
      () => TrackingPublicationPolicy(minimumInterval: Duration.zero),
      throwsArgumentError,
    );
    expect(
      () => TrackingPublicationPolicy(minimumDistanceMeters: 0),
      throwsArgumentError,
    );
    expect(
      () => TrackingPublicationPolicy(minimumDistanceMeters: double.nan),
      throwsArgumentError,
    );
    expect(
      () => TrackingPublicationPolicy(
        heartbeatInterval: const Duration(seconds: 29),
      ),
      throwsArgumentError,
    );
    expect(
      () => TrackingPublicationPolicy(maxAccuracyMeters: double.infinity),
      throwsArgumentError,
    );
    expect(
      () => TrackingPublicationPolicy(maxFixAge: Duration.zero),
      throwsArgumentError,
    );
    expect(
      () =>
          TrackingPublicationPolicy(maxFutureSkew: const Duration(seconds: -1)),
      throwsArgumentError,
    );
    expect(
      () => TrackingPublicationPolicy(minimumHeadingChangeDegrees: 0),
      throwsArgumentError,
    );
    expect(
      () => TrackingPublicationPolicy(minimumHeadingChangeDegrees: 181),
      throwsArgumentError,
    );
    expect(
      () => TrackingPublicationPolicy(minimumHeadingChangeDegrees: double.nan),
      throwsArgumentError,
    );
  });
}
