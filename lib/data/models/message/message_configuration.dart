/// Configuration message
class MessageConfiguration {
  final Map<String, dynamic> configuration;
  final int tst;

  const MessageConfiguration({
    required this.configuration,
    required this.tst,
  });

  factory MessageConfiguration.fromJson(Map<String, dynamic> json) {
    return MessageConfiguration(
      configuration: json['configuration'] as Map<String, dynamic>? ?? {},
      tst: json['tst'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_type': 'configuration',
      'configuration': configuration,
      'tst': tst,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MessageConfiguration && other.tst == tst;
  }

  @override
  int get hashCode => tst.hashCode;
}
