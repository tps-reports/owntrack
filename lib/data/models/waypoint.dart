/// Represents a waypoint/location marker
class Waypoint {
  final String id;
  final double lat;
  final double lon;
  final int timestamp;
  final String description;
  final double radius;
  final String trackerId;
  final bool? shared;

  const Waypoint({
    required this.id,
    required this.lat,
    required this.lon,
    required this.timestamp,
    this.description = '',
    this.radius = 100.0,
    this.trackerId = '',
    this.shared,
  });

  factory Waypoint.fromJson(Map<String, dynamic> json) {
    return Waypoint(
      id: json['id'] as String,
      lat: (json['lat'] as num).toDouble(),
      lon: (json['lon'] as num).toDouble(),
      timestamp: json['timestamp'] as int,
      description: json['description'] as String? ?? '',
      radius: (json['radius'] as num?)?.toDouble() ?? 100.0,
      trackerId: json['trackerId'] as String? ?? '',
      shared: json['shared'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'lat': lat,
      'lon': lon,
      'timestamp': timestamp,
      if (description.isNotEmpty) 'description': description,
      'radius': radius,
      if (trackerId.isNotEmpty) 'trackerId': trackerId,
      if (shared != null) 'shared': shared,
    };
  }

  /// Get display description (fallback if empty)
  String get displayDescription =>
      description.isEmpty ? 'Waypoint at ${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)}' : description;

  /// Convert timestamp to DateTime
  DateTime get dateTime =>
      DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);

  Waypoint copyWith({
    String? id,
    double? lat,
    double? lon,
    int? timestamp,
    String? description,
    double? radius,
    String? trackerId,
    bool? shared,
  }) {
    return Waypoint(
      id: id ?? this.id,
      lat: lat ?? this.lat,
      lon: lon ?? this.lon,
      timestamp: timestamp ?? this.timestamp,
      description: description ?? this.description,
      radius: radius ?? this.radius,
      trackerId: trackerId ?? this.trackerId,
      shared: shared ?? this.shared,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Waypoint && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
