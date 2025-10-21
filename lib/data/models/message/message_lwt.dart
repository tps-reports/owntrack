/// LWT (Last Will and Testament) message
class MessageLwt {
  final int tst;

  const MessageLwt({
    required this.tst,
  });

  factory MessageLwt.fromJson(Map<String, dynamic> json) {
    return MessageLwt(
      tst: json['tst'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_type': 'lwt',
      'tst': tst,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MessageLwt && other.tst == tst;
  }

  @override
  int get hashCode => tst.hashCode;
}
