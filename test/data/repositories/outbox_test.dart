import 'dart:io';
import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:owntrack/data/datasources/local/preferences/settings_local_datasource.dart';
import 'package:owntrack/data/datasources/outbox/outbox_store_native.dart';
import 'package:owntrack/data/repositories/message_queue_repository.dart';

void main() {
  late Directory directory;
  late File file;
  late SettingsLocalDataSource preferences;
  Future<MessageQueueRepository> open() => MessageQueueRepository.open(
    preferences,
    store: SqliteOutboxStore(NativeDatabase(file)),
  );
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('owntrack-outbox-test-');
    file = File('${directory.path}/queue.sqlite');
    SharedPreferences.setMockInitialValues({});
    preferences = SettingsLocalDataSource(
      await SharedPreferences.getInstance(),
    );
  });
  tearDown(() async => directory.delete(recursive: true));
  test(
    'accepted messages survive restart and acknowledgement is durable',
    () async {
      var queue = await open();
      final id = await queue.enqueue(
        'owntracks/a/b',
        '{"_type":"location"}',
        destination: 'endpoint-a',
      );
      await queue.close();
      queue = await open();
      expect(queue.peek()!.id, id);
      expect(queue.peek()!.destination, 'endpoint-a');
      await queue.dequeue(id);
      await queue.close();
      queue = await open();
      expect(queue.isEmpty, isTrue);
      await queue.close();
    },
  );
  test('message identities are never reused after the queue drains', () async {
    final queue = await open();
    final first = await queue.enqueue('a', 'one', destination: 'endpoint');
    await queue.dequeue(first);
    final second = await queue.enqueue('a', 'two', destination: 'endpoint');
    expect(second, greaterThan(first));
    await queue.dequeue(first);
    expect(queue.peek()!.payload, 'two');
    await queue.close();
  });

  test('refresh observes durable writes from another session', () async {
    final first = await open();
    final second = await open();
    await second.enqueue('a', 'two', destination: 'endpoint');
    await first.refresh();
    expect(first.peek()!.payload, 'two');
    await first.close();
    await second.close();
  });

  test('parallel writers do not overwrite accepted messages', () async {
    final first = await open();
    final second = await open();
    await Future.wait([
      first.enqueue('a', 'one', destination: 'endpoint'),
      second.enqueue('a', 'two', destination: 'endpoint'),
    ]);
    await first.close();
    await second.close();
    final reopened = await open();
    expect(reopened.getAllMessages().map((m) => m.payload).toSet(), {
      'one',
      'two',
    });
    await reopened.close();
  });
  test(
    'export preserves selected blocked payloads without removing them',
    () async {
      final queue = await open();
      final legacy = await queue.enqueue(
        'owntracks/a/b',
        '{"_type":"encrypted","data":"original"}',
      );
      await queue.enqueue('owntracks/c/d', 'unselected', destination: 'other');
      final exported =
          jsonDecode(await queue.exportMessages({legacy}))
              as Map<String, dynamic>;
      final messages = exported['messages'] as List<dynamic>;
      expect(messages, hasLength(1));
      expect(messages.single, queue.getAllMessages().first.toJson());
      expect(queue.size, 2);
      await queue.close();
    },
  );

  test('discard only removes selected IDs and survives restart', () async {
    final queue = await open();
    final selected = await queue.enqueue('a', 'selected');
    final ids = {selected};
    final otherSession = await open();
    final newer = await otherSession.enqueue('a', 'newer');
    final discard = queue.discardMessages(ids);
    ids.add(newer);
    expect(await discard, 1);
    await queue.close();
    await otherSession.close();
    final reopened = await open();
    expect(reopened.getAllMessages().map((message) => message.id), [newer]);
    await reopened.close();
  });

  test('manual retry only resets matching destination schedules', () async {
    final queue = await open();
    final matching = await queue.enqueue(
      'a',
      'current',
      destination: 'current',
    );
    final blocked = await queue.enqueue('a', 'blocked', destination: 'old');
    await queue.incrementRetry(matching, retryAt: 9999999999);
    await queue.incrementRetry(blocked, retryAt: 9999999999);
    await queue.retryDestination('current');
    expect(queue.getAllMessages().first.retryAt, 0);
    expect(queue.getAllMessages().first.retryCount, 1);
    expect(queue.getAllMessages().last.retryAt, 9999999999);
    await queue.close();
  });

  test(
    'migration preserves identical records without duplicating a retried migration',
    () async {
      final queue = await open();
      await queue.enqueue('a', 'same');
      final original = queue.peek()!.toJson();
      await queue.close();
      final restored = jsonEncode([
        original,
        {...original, 'id': 42},
      ]);
      await preferences.setString('message_queue_storage', restored);
      final migrated = await open();
      expect(migrated.size, 2);
      expect(
        migrated.getAllMessages().map((message) => message.id).toSet(),
        hasLength(2),
      );
      await migrated.close();
      await preferences.setString('message_queue_storage', restored);
      final retried = await open();
      expect(retried.size, 2);
      await retried.close();
    },
  );
  test(
    'legacy records remain blocked until their unknown destination is resolved',
    () async {
      await preferences.setString(
        'message_queue_storage',
        jsonEncode([
          {
            'id': 1,
            'topic': 'a',
            'payload': '{}',
            'qos': 1,
            'timestamp': 10,
            'retryCount': 0,
          },
        ]),
      );
      final queue = await open();
      expect(queue.size, 1);
      expect(queue.peek()!.destination, isNull);
      expect(preferences.getString('message_queue_storage'), isNull);
      await queue.close();
    },
  );
  test(
    'malformed legacy data blocks startup and preserves the original',
    () async {
      await preferences.setString('message_queue_storage', '[broken');
      await expectLater(open(), throwsFormatException);
      expect(preferences.getString('message_queue_storage'), '[broken');
    },
  );
  test(
    'restored legacy preferences merge into an existing durable outbox',
    () async {
      final queue = await open();
      final original = await queue.enqueue(
        'a',
        'already durable',
        destination: 'current',
      );
      await queue.close();
      await preferences.setString(
        'message_queue_storage',
        jsonEncode([
          {
            'id': original,
            'topic': 'a',
            'payload': 'restored legacy',
            'qos': 1,
            'timestamp': 10,
          },
        ]),
      );
      final reopened = await open();
      expect(reopened.getAllMessages().map((m) => m.payload).toSet(), {
        'already durable',
        'restored legacy',
      });
      expect(reopened.getAllMessages().map((m) => m.id).toSet(), hasLength(2));
      expect(reopened.getAllMessages().last.destination, isNull);
      expect(preferences.getString('message_queue_storage'), isNull);
      await reopened.close();
    },
  );
}
