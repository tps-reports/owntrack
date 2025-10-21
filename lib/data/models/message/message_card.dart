/// Card message (user info)
class MessageCard {
  final String name;
  final String face;

  const MessageCard({
    required this.name,
    required this.face,
  });

  factory MessageCard.fromJson(Map<String, dynamic> json) {
    return MessageCard(
      name: json['name'] as String,
      face: json['face'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_type': 'card',
      'name': name,
      'face': face,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MessageCard && other.name == name;
  }

  @override
  int get hashCode => name.hashCode;
}
