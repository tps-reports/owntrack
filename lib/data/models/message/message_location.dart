/// Location message
class MessageLocation {
  final double lat;
  final double lon;
  final int tst;
  final int acc;
  final int alt;
  final int batt;
  final int bs;
  final int conn;
  final double vel;
  final double vac;
  final int cog;
  final String tid;
  final String t;
  final List<String> inregions;
  final List<String> inrids;

  const MessageLocation({
    required this.lat,
    required this.lon,
    required this.tst,
    this.acc = 0,
    this.alt = 0,
    this.batt = 0,
    this.bs = 0,
    this.conn = 0,
    this.vel = 0,
    this.vac = 0,
    this.cog = 0,
    this.tid = '',
    this.t = '',
    this.inregions = const [],
    this.inrids = const [],
  });

  factory MessageLocation.fromJson(Map<String, dynamic> json) {
    return MessageLocation(
      lat: (json['lat'] as num).toDouble(),
      lon: (json['lon'] as num).toDouble(),
      tst: json['tst'] as int,
      acc: json['acc'] as int? ?? 0,
      alt: json['alt'] as int? ?? 0,
      batt: json['batt'] as int? ?? 0,
      bs: json['bs'] as int? ?? 0,
      conn: json['conn'] as int? ?? 0,
      vel: (json['vel'] as num?)?.toDouble() ?? 0,
      vac: (json['vac'] as num?)?.toDouble() ?? 0,
      cog: json['cog'] as int? ?? 0,
      tid: json['tid'] as String? ?? '',
      t: json['t'] as String? ?? '',
      inregions: (json['inregions'] as List<dynamic>?)?.cast<String>() ?? const [],
      inrids: (json['inrids'] as List<dynamic>?)?.cast<String>() ?? const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_type': 'location',
      'lat': lat,
      'lon': lon,
      'tst': tst,
      'acc': acc,
      'alt': alt,
      'batt': batt,
      'bs': bs,
      'conn': conn,
      'vel': vel,
      'vac': vac,
      'cog': cog,
      'tid': tid,
      't': t,
      if (inregions.isNotEmpty) 'inregions': inregions,
      if (inrids.isNotEmpty) 'inrids': inrids,
    };
  }

  MessageLocation copyWith({
    double? lat,
    double? lon,
    int? tst,
    int? acc,
    int? alt,
    int? batt,
    int? bs,
    int? conn,
    double? vel,
    double? vac,
    int? cog,
    String? tid,
    String? t,
    List<String>? inregions,
    List<String>? inrids,
  }) {
    return MessageLocation(
      lat: lat ?? this.lat,
      lon: lon ?? this.lon,
      tst: tst ?? this.tst,
      acc: acc ?? this.acc,
      alt: alt ?? this.alt,
      batt: batt ?? this.batt,
      bs: bs ?? this.bs,
      conn: conn ?? this.conn,
      vel: vel ?? this.vel,
      vac: vac ?? this.vac,
      cog: cog ?? this.cog,
      tid: tid ?? this.tid,
      t: t ?? this.t,
      inregions: inregions ?? this.inregions,
      inrids: inrids ?? this.inrids,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MessageLocation &&
        other.lat == lat &&
        other.lon == lon &&
        other.tst == tst;
  }

  @override
  int get hashCode => Object.hash(lat, lon, tst);
}
