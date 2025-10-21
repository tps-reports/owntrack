/// Transition message (geofence enter/exit)
class MessageTransition {
  final String event;
  final double lat;
  final double lon;
  final int tst;
  final String desc;
  final String tid;
  final int acc;
  final String? wtst;

  const MessageTransition({
    required this.event,
    required this.lat,
    required this.lon,
    required this.tst,
    required this.desc,
    this.tid = '',
    this.acc = 0,
    this.wtst,
  });

  factory MessageTransition.fromJson(Map<String, dynamic> json) {
    return MessageTransition(
      event: json['event'] as String,
      lat: (json['lat'] as num).toDouble(),
      lon: (json['lon'] as num).toDouble(),
      tst: json['tst'] as int,
      desc: json['desc'] as String,
      tid: json['tid'] as String? ?? '',
      acc: json['acc'] as int? ?? 0,
      wtst: json['wtst'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_type': 'transition',
      'event': event,
      'lat': lat,
      'lon': lon,
      'tst': tst,
      'desc': desc,
      'tid': tid,
      'acc': acc,
      if (wtst != null) 'wtst': wtst,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MessageTransition &&
        other.event == event &&
        other.lat == lat &&
        other.lon == lon &&
        other.tst == tst;
  }

  @override
  int get hashCode => Object.hash(event, lat, lon, tst);
}
