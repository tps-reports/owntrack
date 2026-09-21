import 'package:latlong2/latlong.dart';
import 'package:owntrack/data/models/location_update.dart';

/// Decides whether a fresh location should enter the durable delivery queue.
///
/// Scheduling uses elapsed monotonic time supplied by the caller. Wall time is
/// used only to assess GPS fix freshness, so clock corrections cannot bypass
/// the minimum interval or delay a stationary heartbeat.
class TrackingPublicationPolicy {
  final Duration minimumInterval;
  final double minimumDistanceMeters;
  final Duration heartbeatInterval;
  final double maxAccuracyMeters;
  final Duration maxFixAge;
  final Duration maxFutureSkew;
  final double? minimumHeadingChangeDegrees;

  TrackingPublicationPolicy({
    this.minimumInterval = const Duration(seconds: 30),
    this.minimumDistanceMeters = 50,
    this.heartbeatInterval = const Duration(minutes: 5),
    this.maxAccuracyMeters = 100,
    this.maxFixAge = const Duration(minutes: 2),
    this.maxFutureSkew = const Duration(seconds: 30),
    this.minimumHeadingChangeDegrees,
  }) {
    if (minimumInterval <= Duration.zero) {
      throw ArgumentError.value(
        minimumInterval,
        'minimumInterval',
        'Must be positive.',
      );
    }
    if (!minimumDistanceMeters.isFinite || minimumDistanceMeters <= 0) {
      throw ArgumentError.value(
        minimumDistanceMeters,
        'minimumDistanceMeters',
        'Must be finite and positive.',
      );
    }
    if (heartbeatInterval < minimumInterval) {
      throw ArgumentError.value(
        heartbeatInterval,
        'heartbeatInterval',
        'Must be at least the minimum interval.',
      );
    }
    if (!maxAccuracyMeters.isFinite || maxAccuracyMeters <= 0) {
      throw ArgumentError.value(
        maxAccuracyMeters,
        'maxAccuracyMeters',
        'Must be finite and positive.',
      );
    }
    if (maxFixAge <= Duration.zero) {
      throw ArgumentError.value(maxFixAge, 'maxFixAge', 'Must be positive.');
    }
    if (maxFutureSkew < Duration.zero) {
      throw ArgumentError.value(
        maxFutureSkew,
        'maxFutureSkew',
        'Must not be negative.',
      );
    }
    final headingThreshold = minimumHeadingChangeDegrees;
    if (headingThreshold != null &&
        (!headingThreshold.isFinite ||
            headingThreshold <= 0 ||
            headingThreshold > 180)) {
      throw ArgumentError.value(
        headingThreshold,
        'minimumHeadingChangeDegrees',
        'Must be greater than 0 and at most 180 degrees.',
      );
    }
  }

  bool isAcceptable(LocationUpdate location, {required DateTime now}) {
    final age = now.difference(location.timestamp);
    return location.latitude.isFinite &&
        location.latitude.abs() <= 90 &&
        location.longitude.isFinite &&
        location.longitude.abs() <= 180 &&
        location.accuracy.isFinite &&
        location.accuracy >= 0 &&
        location.accuracy <= maxAccuracyMeters &&
        !location.isMocked &&
        age <= maxFixAge &&
        age >= -maxFutureSkew;
  }

  bool shouldPublish(
    LocationUpdate location, {
    required DateTime now,
    required Duration elapsedSincePublication,
    LocationUpdate? lastPublishedLocation,
  }) {
    if (!isAcceptable(location, now: now)) return false;
    if (lastPublishedLocation == null) return true;
    if (elapsedSincePublication < minimumInterval) return false;
    if (elapsedSincePublication >= heartbeatInterval) return true;

    const distance = DistanceHaversine(roundResult: false);
    final movement = distance(
      LatLng(lastPublishedLocation.latitude, lastPublishedLocation.longitude),
      LatLng(location.latitude, location.longitude),
    );
    if (movement >= minimumDistanceMeters) return true;

    final headingThreshold = minimumHeadingChangeDegrees;
    if (headingThreshold == null ||
        movement <= location.accuracy + lastPublishedLocation.accuracy ||
        !_hasMovingHeading(location) ||
        !_hasMovingHeading(lastPublishedLocation)) {
      return false;
    }
    final difference = (location.heading! - lastPublishedLocation.heading!)
        .abs();
    final shortestAngle = difference > 180 ? 360 - difference : difference;
    return shortestAngle >= headingThreshold;
  }

  bool _hasMovingHeading(LocationUpdate location) {
    final heading = location.heading;
    final speed = location.speed;
    return heading != null &&
        heading.isFinite &&
        heading >= 0 &&
        heading < 360 &&
        speed != null &&
        speed.isFinite &&
        speed > 0;
  }
}
