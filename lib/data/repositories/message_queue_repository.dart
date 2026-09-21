import 'dart:async';
import 'dart:convert';
import 'package:owntrack/data/datasources/local/preferences/settings_local_datasource.dart';
import 'package:owntrack/data/datasources/outbox/outbox_store.dart';

class QueuedMessage {
  final int id;
  final String topic;
  final String payload;
  final int qos;
  final int timestamp;
  final int retryCount;
  final int retryAt;

  /// A missing identity marks legacy records as blocked, never implicitly rerouted.
  final String? destination;
  const QueuedMessage({
    required this.id,
    required this.topic,
    required this.payload,
    required this.qos,
    required this.timestamp,
    this.retryCount = 0,
    this.retryAt = 0,
    this.destination,
  });

  factory QueuedMessage.fromJson(Object? value) {
    if (value is! Map<String, dynamic> ||
        value['id'] is! int ||
        value['topic'] is! String ||
        value['payload'] is! String ||
        value['qos'] is! int ||
        value['timestamp'] is! int ||
        (value['retryCount'] != null && value['retryCount'] is! int) ||
        (value['retryAt'] != null && value['retryAt'] is! int) ||
        (value['destination'] != null && value['destination'] is! String)) {
      throw const FormatException(
        'Outbox contains an invalid record; original storage retained.',
      );
    }
    final id = value['id'] as int;
    final qos = value['qos'] as int;
    if (id < 1 || qos < 0 || qos > 2) {
      throw const FormatException('Invalid outbox identity or QoS.');
    }
    return QueuedMessage(
      id: id,
      topic: value['topic'] as String,
      payload: value['payload'] as String,
      qos: qos,
      timestamp: value['timestamp'] as int,
      retryCount: value['retryCount'] as int? ?? 0,
      retryAt: value['retryAt'] as int? ?? 0,
      destination: value['destination'] as String?,
    );
  }
  Map<String, dynamic> toJson() => {
    'id': id,
    'topic': topic,
    'payload': payload,
    'qos': qos,
    'timestamp': timestamp,
    'retryCount': retryCount,
    'retryAt': retryAt,
    'destination': destination,
  };
  QueuedMessage copyWith({int? retryCount, int? retryAt}) => QueuedMessage(
    id: id,
    topic: topic,
    payload: payload,
    qos: qos,
    timestamp: timestamp,
    retryCount: retryCount ?? this.retryCount,
    retryAt: retryAt ?? this.retryAt,
    destination: destination,
  );
}

/// Commits acceptance and acknowledgement before exposing the updated snapshot.
class MessageQueueRepository {
  static const _queueKey = 'message_queue_storage';
  final OutboxStore _store;
  List<QueuedMessage> _messages = [];
  Future<void> _writes = Future.value();
  final _changes = StreamController<int>.broadcast();
  bool _closed = false;
  MessageQueueRepository._(this._store);
  Stream<int> get changes => _changes.stream;

  static List<QueuedMessage> _decode(String raw) {
    final snapshot = jsonDecode(raw);
    final decoded = snapshot is Map<String, dynamic> && snapshot['version'] == 1
        ? snapshot['messages']
        : snapshot;
    if (decoded is! List) {
      throw const FormatException('Invalid outbox snapshot.');
    }
    final messages = decoded.map(QueuedMessage.fromJson).toList();
    if (messages.map((m) => m.id).toSet().length != messages.length) {
      throw const FormatException('Duplicate outbox identity.');
    }
    return messages;
  }

  static Future<MessageQueueRepository> open(
    SettingsLocalDataSource preferences, {
    required OutboxStore store,
  }) async {
    final repository = MessageQueueRepository._(store);
    try {
      final legacy = preferences.getString(_queueKey);
      final migrated = legacy == null ? <QueuedMessage>[] : _decode(legacy);
      var raw = await store.read();
      if (raw == null) {
        final snapshot = jsonEncode(migrated.map((m) => m.toJson()).toList());
        await store.compareAndSet(null, snapshot);
        raw = await store.read();
      }
      repository._messages = _decode(raw!);
      if (migrated.isNotEmpty) {
        await repository._mutate((messages, nextId) {
          String contents(QueuedMessage message) =>
              jsonEncode(message.toJson()..remove('id'));
          final existing = <String, int>{};
          for (final message in messages) {
            final key = contents(message);
            existing[key] = (existing[key] ?? 0) + 1;
          }
          for (final message in migrated) {
            final key = contents(message);
            final count = existing[key] ?? 0;
            if (count == 0) {
              messages.add(
                QueuedMessage.fromJson({...message.toJson(), 'id': nextId++}),
              );
            } else {
              existing[key] = count - 1;
            }
          }
        });
      }
      if (preferences.containsKey(_queueKey) &&
          !await preferences.remove(_queueKey)) {
        throw StateError('Cannot finalize outbox migration. Retry startup.');
      }
      return repository;
    } catch (_) {
      await store.close();
      rethrow;
    }
  }

  Future<T> _mutate<T>(T Function(List<QueuedMessage>, int) change) {
    final result = Completer<T>();
    _writes = _writes.then((_) async {
      try {
        if (_closed) throw StateError('Outbox is closed.');
        for (var attempt = 0; attempt < 20; attempt++) {
          final raw = await _store.read();
          final candidate = _decode(raw!);
          final snapshot = jsonDecode(raw);
          final previousNextId = snapshot is Map<String, dynamic>
              ? snapshot['nextId']
              : null;
          if (previousNextId != null &&
              (previousNextId is! int || previousNextId < 1)) {
            throw const FormatException('Invalid outbox sequence.');
          }
          var nextId = previousNextId as int? ?? 1;
          for (final message in candidate) {
            if (message.id >= nextId) nextId = message.id + 1;
          }
          final value = change(candidate, nextId);
          for (final message in candidate) {
            if (message.id >= nextId) nextId = message.id + 1;
          }
          final encoded = jsonEncode({
            'version': 1,
            'nextId': nextId,
            'messages': candidate.map((m) => m.toJson()).toList(),
          });
          if (candidate.length > 10000 ||
              utf8.encode(encoded).length > 20 * 1024 * 1024) {
            throw StateError(
              'Outbox is full. Restore delivery before accepting more locations.',
            );
          }
          if (await _store.compareAndSet(raw, encoded)) {
            _messages = candidate;
            _changes.add(size);
            result.complete(value);
            return;
          }
        }
        throw StateError(
          'Outbox is busy in another session. Retry the operation.',
        );
      } catch (error, stack) {
        result.completeError(error, stack);
      }
    });
    return result.future;
  }

  Future<int> enqueue(
    String topic,
    String payload, {
    int qos = 1,
    String? destination,
  }) => _mutate((messages, nextId) {
    if (qos < 0 || qos > 2) throw ArgumentError.value(qos, 'qos');
    final id = nextId;
    messages.add(
      QueuedMessage(
        id: id,
        topic: topic,
        payload: payload,
        qos: qos,
        timestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        destination: destination,
      ),
    );
    return id;
  });
  QueuedMessage? peek() => _messages.isEmpty ? null : _messages.first;

  /// Refresh through the same serialized transaction path as writes so another
  /// tab's commits cannot overwrite this session's newer in-flight snapshot.
  Future<void> refresh() => _mutate((messages, nextId) {});
  Future<void> dequeue(int id) => _mutate((messages, nextId) {
    messages.removeWhere((m) => m.id == id);
  });
  Future<void> incrementRetry(int id, {int retryAt = 0}) =>
      _mutate((messages, nextId) {
        final index = messages.indexWhere((m) => m.id == id);
        if (index >= 0) {
          messages[index] = messages[index].copyWith(
            retryCount: messages[index].retryCount + 1,
            retryAt: retryAt,
          );
        }
      });
  List<QueuedMessage> getAllMessages() => List.unmodifiable(_messages);

  /// Export the stored envelopes without decrypting or redirecting them.
  Future<String> exportMessages(Set<int> ids) {
    final selected = Set<int>.of(ids);
    return _mutate(
      (messages, nextId) => jsonEncode({
        'format': 'owntrack-outbox-export',
        'version': 1,
        'messages': messages
            .where((message) => selected.contains(message.id))
            .map((message) => message.toJson())
            .toList(),
      }),
    );
  }

  /// The confirmation applies only to its snapshot of selected IDs. Messages
  /// accepted while the user reviews it must survive.
  Future<int> discardMessages(Set<int> ids) {
    final selected = Set<int>.of(ids);
    return _mutate((messages, nextId) {
      final before = messages.length;
      messages.removeWhere((message) => selected.contains(message.id));
      return before - messages.length;
    });
  }

  Future<void> retryDestination(String destination) =>
      _mutate((messages, nextId) {
        for (var i = 0; i < messages.length; i++) {
          if (messages[i].destination == destination) {
            messages[i] = messages[i].copyWith(retryAt: 0);
          }
        }
      });

  Future<void> clearAll() => _mutate((messages, nextId) {
    messages.clear();
  });
  int get size => _messages.length;
  bool get isEmpty => _messages.isEmpty;
  Future<void> close() async {
    await _writes;
    _closed = true;
    await _changes.close();
    await _store.close();
  }
}
