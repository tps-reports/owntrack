import 'dart:convert';

import 'package:owntrack/data/datasources/local/preferences/settings_local_datasource.dart';

/// Queued message model
class QueuedMessage {
  final int id;
  final String topic;
  final String payload;
  final int qos;
  final int timestamp;
  final int retryCount;

  const QueuedMessage({
    required this.id,
    required this.topic,
    required this.payload,
    required this.qos,
    required this.timestamp,
    this.retryCount = 0,
  });

  factory QueuedMessage.fromJson(Map<String, dynamic> json) {
    return QueuedMessage(
      id: json['id'] as int,
      topic: json['topic'] as String,
      payload: json['payload'] as String,
      qos: json['qos'] as int,
      timestamp: json['timestamp'] as int,
      retryCount: json['retryCount'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'topic': topic,
      'payload': payload,
      'qos': qos,
      'timestamp': timestamp,
      'retryCount': retryCount,
    };
  }

  QueuedMessage copyWith({
    int? id,
    String? topic,
    String? payload,
    int? qos,
    int? timestamp,
    int? retryCount,
  }) {
    return QueuedMessage(
      id: id ?? this.id,
      topic: topic ?? this.topic,
      payload: payload ?? this.payload,
      qos: qos ?? this.qos,
      timestamp: timestamp ?? this.timestamp,
      retryCount: retryCount ?? this.retryCount,
    );
  }
}

/// Repository for message queue with retry logic
class MessageQueueRepository {
  static const String _queueKey = 'message_queue_storage';

  final SettingsLocalDataSource _localDataSource;
  final Map<int, QueuedMessage> _queue = {};
  int _nextId = 1;

  MessageQueueRepository(this._localDataSource) {
    _loadQueue();
  }

  /// Load queue from storage
  void _loadQueue() {
    final jsonString = _localDataSource.getString(_queueKey);
    if (jsonString != null && jsonString.isNotEmpty) {
      try {
        final List<dynamic> jsonList = json.decode(jsonString);
        for (final json in jsonList) {
          final message = QueuedMessage.fromJson(json as Map<String, dynamic>);
          _queue[message.id] = message;
          if (message.id >= _nextId) {
            _nextId = message.id + 1;
          }
        }
      } catch (e) {
        // Handle parsing errors
      }
    }
  }

  /// Save queue to storage
  Future<void> _saveQueue() async {
    final jsonList = _queue.values.map((m) => m.toJson()).toList();
    final jsonString = json.encode(jsonList);
    await _localDataSource.setString(_queueKey, jsonString);
  }

  /// Add message to queue
  Future<int> enqueue(String topic, String payload, {int qos = 1}) async {
    final message = QueuedMessage(
      id: _nextId++,
      topic: topic,
      payload: payload,
      qos: qos,
      timestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
    _queue[message.id] = message;
    await _saveQueue();
    return message.id;
  }

  /// Get next message from queue
  QueuedMessage? peek() {
    if (_queue.isEmpty) return null;
    // Get oldest message (lowest timestamp)
    return _queue.values.reduce((a, b) => a.timestamp < b.timestamp ? a : b);
  }

  /// Remove message from queue
  Future<void> dequeue(int id) async {
    if (_queue.remove(id) != null) {
      await _saveQueue();
    }
  }

  /// Increment retry count for a message
  Future<void> incrementRetry(int id) async {
    final message = _queue[id];
    if (message != null) {
      _queue[id] = message.copyWith(retryCount: message.retryCount + 1);
      await _saveQueue();
    }
  }

  /// Get all messages in queue
  List<QueuedMessage> getAllMessages() {
    return _queue.values.toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  /// Clear all messages
  Future<void> clearAll() async {
    _queue.clear();
    await _saveQueue();
  }

  /// Get queue size
  int get size => _queue.length;

  /// Check if queue is empty
  bool get isEmpty => _queue.isEmpty;
}
