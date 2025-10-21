/// Waypoint message
class MessageWaypoint {
  final double lat;
  final double lon;
  final int tst;
  final String desc;
  final String rad;
  final String tid;

  const MessageWaypoint({
    required this.lat,
    required this.lon,
    required this.tst,
    this.desc = '',
    this.rad = '',
    this.tid = '',
  });

  factory MessageWaypoint.fromJson(Map<String, dynamic> json) {
    return MessageWaypoint(
      lat: (json['lat'] as num).toDouble(),
      lon: (json['lon'] as num).toDouble(),
      tst: json['tst'] as int,
      desc: json['desc'] as String? ?? '',
      rad: json['rad'] as String? ?? '',
      tid: json['tid'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_type': 'waypoint',
      'lat': lat,
      'lon': lon,
      'tst': tst,
      if (desc.isNotEmpty) 'desc': desc,
      if (rad.isNotEmpty) 'rad': rad,
      if (tid.isNotEmpty) 'tid': tid,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MessageWaypoint &&
        other.lat == lat &&
        other.lon == lon &&
        other.tst == tst;
  }

  @override
  int get hashCode => Object.hash(lat, lon, tst);
}
