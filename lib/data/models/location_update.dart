/// Represents a location update from the device
class LocationUpdate {
  final double latitude;
  final double longitude;
  final double accuracy;
  final DateTime timestamp;
  final double? altitude;
  final double? speed;
  final double? heading;
  final int? battery;
  final bool isMocked;

  const LocationUpdate({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.timestamp,
    this.altitude,
    this.speed,
    this.heading,
    this.battery,
    this.isMocked = false,
  });

  factory LocationUpdate.fromJson(Map<String, dynamic> json) {
    return LocationUpdate(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      accuracy: (json['accuracy'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
      altitude: (json['altitude'] as num?)?.toDouble(),
      speed: (json['speed'] as num?)?.toDouble(),
      heading: (json['heading'] as num?)?.toDouble(),
      battery: json['battery'] as int?,
      isMocked: json['isMocked'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'timestamp': timestamp.toIso8601String(),
      if (altitude != null) 'altitude': altitude,
      if (speed != null) 'speed': speed,
      if (heading != null) 'heading': heading,
      if (battery != null) 'battery': battery,
      'isMocked': isMocked,
    };
  }

  /// Get Unix timestamp in seconds
  int get timestampSeconds => timestamp.millisecondsSinceEpoch ~/ 1000;

  /// Check if location is accurate enough (< 50m)
  bool get isAccurate => accuracy < 50;

  /// Get speed in km/h (if available)
  double? get speedKmH => speed != null ? speed! * 3.6 : null;

  LocationUpdate copyWith({
    double? latitude,
    double? longitude,
    double? accuracy,
    DateTime? timestamp,
    double? altitude,
    double? speed,
    double? heading,
    int? battery,
    bool? isMocked,
  }) {
    return LocationUpdate(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracy: accuracy ?? this.accuracy,
      timestamp: timestamp ?? this.timestamp,
      altitude: altitude ?? this.altitude,
      speed: speed ?? this.speed,
      heading: heading ?? this.heading,
      battery: battery ?? this.battery,
      isMocked: isMocked ?? this.isMocked,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LocationUpdate &&
        other.latitude == latitude &&
        other.longitude == longitude &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode => Object.hash(latitude, longitude, timestamp);
}
