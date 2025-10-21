/// Represents a tracked friend/contact
class Friend {
  final String id;
  final String topic;
  final String? name;
  final String? imageUrl;
  final double? lat;
  final double? lon;
  final int? timestamp;
  final int? accuracy;
  final int? battery;
  final double? velocity;
  final String? trackerId;
  final List<String> inRegions;

  const Friend({
    required this.id,
    required this.topic,
    this.name,
    this.imageUrl,
    this.lat,
    this.lon,
    this.timestamp,
    this.accuracy,
    this.battery,
    this.velocity,
    this.trackerId,
    this.inRegions = const [],
  });

  factory Friend.fromJson(Map<String, dynamic> json) {
    return Friend(
      id: json['id'] as String,
      topic: json['topic'] as String,
      name: json['name'] as String?,
      imageUrl: json['imageUrl'] as String?,
      lat: (json['lat'] as num?)?.toDouble(),
      lon: (json['lon'] as num?)?.toDouble(),
      timestamp: json['timestamp'] as int?,
      accuracy: json['accuracy'] as int?,
      battery: json['battery'] as int?,
      velocity: (json['velocity'] as num?)?.toDouble(),
      trackerId: json['trackerId'] as String?,
      inRegions: (json['inRegions'] as List<dynamic>?)?.cast<String>() ?? const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'topic': topic,
      if (name != null) 'name': name,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (lat != null) 'lat': lat,
      if (lon != null) 'lon': lon,
      if (timestamp != null) 'timestamp': timestamp,
      if (accuracy != null) 'accuracy': accuracy,
      if (battery != null) 'battery': battery,
      if (velocity != null) 'velocity': velocity,
      if (trackerId != null) 'trackerId': trackerId,
      if (inRegions.isNotEmpty) 'inRegions': inRegions,
    };
  }

  /// Get display name (fallback to topic if name is not set)
  String get displayName => name ?? topic.split('/').last;

  /// Check if location is available
  bool get hasLocation => lat != null && lon != null;

  /// Check if friend has recent location (within last hour)
  bool get hasRecentLocation {
    if (timestamp == null) return false;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final hourAgo = now - 3600;
    return timestamp! > hourAgo;
  }

  /// Get battery percentage as string
  String get batteryPercentage =>
      battery != null ? '$battery%' : 'Unknown';

  Friend copyWith({
    String? id,
    String? topic,
    String? name,
    String? imageUrl,
    double? lat,
    double? lon,
    int? timestamp,
    int? accuracy,
    int? battery,
    double? velocity,
    String? trackerId,
    List<String>? inRegions,
  }) {
    return Friend(
      id: id ?? this.id,
      topic: topic ?? this.topic,
      name: name ?? this.name,
      imageUrl: imageUrl ?? this.imageUrl,
      lat: lat ?? this.lat,
      lon: lon ?? this.lon,
      timestamp: timestamp ?? this.timestamp,
      accuracy: accuracy ?? this.accuracy,
      battery: battery ?? this.battery,
      velocity: velocity ?? this.velocity,
      trackerId: trackerId ?? this.trackerId,
      inRegions: inRegions ?? this.inRegions,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Friend && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
