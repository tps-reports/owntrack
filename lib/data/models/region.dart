/// Represents a geofence region
class Region {
  final String id;
  final double lat;
  final double lon;
  final double radius;
  final String description;
  final bool enabled;
  final int? timestamp;

  const Region({
    required this.id,
    required this.lat,
    required this.lon,
    required this.radius,
    this.description = '',
    this.enabled = true,
    this.timestamp,
  });

  factory Region.fromJson(Map<String, dynamic> json) {
    return Region(
      id: json['id'] as String,
      lat: (json['lat'] as num).toDouble(),
      lon: (json['lon'] as num).toDouble(),
      radius: (json['radius'] as num).toDouble(),
      description: json['description'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? true,
      timestamp: json['timestamp'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'lat': lat,
      'lon': lon,
      'radius': radius,
      if (description.isNotEmpty) 'description': description,
      'enabled': enabled,
      if (timestamp != null) 'timestamp': timestamp,
    };
  }

  /// Get display description (fallback if empty)
  String get displayDescription =>
      description.isEmpty ? 'Region at ${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)}' : description;

  /// Convert timestamp to DateTime if available
  DateTime? get dateTime => timestamp != null
      ? DateTime.fromMillisecondsSinceEpoch(timestamp! * 1000)
      : null;

  /// Get radius in meters as int
  int get radiusMeters => radius.toInt();

  Region copyWith({
    String? id,
    double? lat,
    double? lon,
    double? radius,
    String? description,
    bool? enabled,
    int? timestamp,
  }) {
    return Region(
      id: id ?? this.id,
      lat: lat ?? this.lat,
      lon: lon ?? this.lon,
      radius: radius ?? this.radius,
      description: description ?? this.description,
      enabled: enabled ?? this.enabled,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Region && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
