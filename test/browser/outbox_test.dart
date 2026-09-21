@TestOn('browser')
library;

import 'dart:async';
import 'dart:js_interop';

import 'package:flutter_test/flutter_test.dart';
import 'package:owntrack/data/datasources/outbox/outbox_store_web.dart';
import 'package:web/web.dart' as web;

Future<web.IDBDatabase> openDatabase(String name, int version) {
  final done = Completer<web.IDBDatabase>();
  final request = web.window.indexedDB.open(name, version);
  request.onupgradeneeded = ((web.Event event) {
    final database = request.result as web.IDBDatabase;
    if (!database.objectStoreNames.contains('snapshot')) {
      database.createObjectStore('snapshot');
    }
  }).toJS;
  request.onsuccess = ((web.Event event) {
    done.complete(request.result as web.IDBDatabase);
  }).toJS;
  request.onerror = ((web.Event event) {
    done.completeError(StateError('Test database could not be opened.'));
  }).toJS;
  return done.future.timeout(const Duration(seconds: 5));
}

Future<void> deleteDatabase(String name) {
  final done = Completer<void>();
  final request = web.window.indexedDB.deleteDatabase(name);
  request.onsuccess = ((web.Event event) {
    done.complete();
  }).toJS;
  request.onerror = ((web.Event event) {
    done.completeError(StateError('Test database could not be deleted.'));
  }).toJS;
  return done.future.timeout(const Duration(seconds: 5));
}

void main() {
  late String databaseName;
  setUp(() {
    databaseName =
        'owntrack-outbox-test-${DateTime.now().microsecondsSinceEpoch}';
  });
  tearDown(() => deleteDatabase(databaseName));

  test(
    'IndexedDB persists across connections and compare-and-swap rejects stale writes',
    () async {
      final first = IndexedDbOutboxStore(databaseName: databaseName);
      final second = IndexedDbOutboxStore(databaseName: databaseName);
      final original = await first.read();
      expect(await first.compareAndSet(original, 'accepted-message'), isTrue);
      expect(await second.read(), 'accepted-message');
      expect(await second.compareAndSet(original, 'stale-overwrite'), isFalse);
      await first.close();
      await second.close();
      final reopened = IndexedDbOutboxStore(databaseName: databaseName);
      expect(await reopened.read(), 'accepted-message');
      expect(
        await reopened.compareAndSet('accepted-message', 'acknowledged'),
        isTrue,
      );
      await reopened.close();
    },
  );

  test('a closed store cannot open a new database connection', () async {
    final store = IndexedDbOutboxStore(databaseName: databaseName);
    await store.close();
    await expectLater(store.read(), throwsStateError);
  });

  test(
    'closing a pending open rejects the read without leaking a connection',
    () async {
      final store = IndexedDbOutboxStore(databaseName: databaseName);
      final rejected = expectLater(store.read(), throwsStateError);
      await store.close();
      await rejected;
      await deleteDatabase(databaseName);
    },
  );

  test(
    'an open store releases its connection for another tab upgrade',
    () async {
      final store = IndexedDbOutboxStore(databaseName: databaseName);
      await store.read();
      try {
        final upgraded = await openDatabase(databaseName, 2);
        upgraded.close();
      } finally {
        await store.close();
      }
    },
  );

  test('a blocked upgrade can retry after the other tab closes', () async {
    final otherTab = await openDatabase(databaseName, 1);
    final store = IndexedDbOutboxStore(
      databaseName: databaseName,
      databaseVersion: 2,
    );
    try {
      await expectLater(
        store.read(),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('Close other OwnTrack tabs'),
          ),
        ),
      );
      otherTab.close();
      expect(await store.read().timeout(const Duration(seconds: 5)), isNull);
      expect(await store.compareAndSet(null, 'recovered'), isTrue);
      expect(await store.read(), 'recovered');
    } finally {
      otherTab.close();
      await store.close();
    }
  });

  test('closing a blocked open leaves no late database connection', () async {
    final otherTab = await openDatabase(databaseName, 1);
    final store = IndexedDbOutboxStore(
      databaseName: databaseName,
      databaseVersion: 2,
    );
    try {
      await expectLater(store.read(), throwsStateError);
      await store.close();
    } finally {
      otherTab.close();
    }
    await deleteDatabase(databaseName);
    await expectLater(store.read(), throwsStateError);
  });
}
