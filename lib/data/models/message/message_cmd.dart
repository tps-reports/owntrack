/// Command message
class MessageCmd {
  final String action;
  final String content;

  const MessageCmd({
    required this.action,
    this.content = '',
  });

  factory MessageCmd.fromJson(Map<String, dynamic> json) {
    return MessageCmd(
      action: json['action'] as String,
      content: json['content'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_type': 'cmd',
      'action': action,
      if (content.isNotEmpty) 'content': content,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MessageCmd && other.action == action;
  }

  @override
  int get hashCode => action.hashCode;
}
