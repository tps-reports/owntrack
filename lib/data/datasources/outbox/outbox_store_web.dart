import 'dart:async';
import 'dart:js_interop';

import 'package:owntrack/data/datasources/outbox/outbox_store.dart';
import 'package:web/web.dart' as web;

OutboxStore createOutboxStore() => IndexedDbOutboxStore();

/// IndexedDB commits the read/compare/write in one browser transaction. A quota
/// error or private-mode restriction propagates; no in-memory fallback can
/// falsely acknowledge durable acceptance.
class IndexedDbOutboxStore implements OutboxStore {
  final String databaseName;
  final int databaseVersion;
  Completer<web.IDBDatabase>? _opening;
  web.IDBDatabase? _database;
  bool _closed = false;

  IndexedDbOutboxStore({
    this.databaseName = 'owntrack-outbox',
    this.databaseVersion = 1,
  });

  Future<web.IDBDatabase> _open() {
    if (_closed) return Future.error(StateError('Outbox is closed.'));
    final database = _database;
    if (database != null) return Future.value(database);
    final opening = _opening;
    if (opening != null) return opening.future;
    final done = Completer<web.IDBDatabase>();
    _opening = done;
    void fail(String message) {
      if (done.isCompleted) return;
      if (identical(_opening, done)) _opening = null;
      done.completeError(StateError(message));
    }

    try {
      final request = web.window.indexedDB.open(databaseName, databaseVersion);
      request.onupgradeneeded = ((web.Event event) {
        // A blocked request stays queued in the browser after its caller gets
        // the error. Cancel that upgrade once the other connection releases it.
        if (done.isCompleted || _closed) {
          request.transaction?.abort();
          return;
        }
        try {
          final database = request.result as web.IDBDatabase;
          if (!database.objectStoreNames.contains('snapshot')) {
            database.createObjectStore('snapshot');
          }
        } catch (_) {
          request.transaction?.abort();
          fail('Cannot initialize persistent outbox');
        }
      }).toJS;
      request.onsuccess = ((web.Event event) {
        final database = request.result as web.IDBDatabase;
        if (done.isCompleted || _closed) {
          database.close();
          fail('Outbox is closed.');
          return;
        }
        _database = database;
        _opening = null;
        database.onversionchange = ((web.Event event) {
          database.close();
          if (identical(_database, database)) _database = null;
        }).toJS;
        done.complete(database);
      }).toJS;
      request.onerror = ((web.Event event) {
        fail('Cannot open persistent outbox');
      }).toJS;
      request.onblocked = ((web.Event event) {
        fail('Close other OwnTrack tabs to upgrade storage');
      }).toJS;
    } catch (_) {
      fail('Cannot open persistent outbox');
    }
    return done.future;
  }

  @override
  Future<String?> read() async {
    final database = await _open();
    final transaction = database.transaction('snapshot'.toJS, 'readonly');
    final request = transaction.objectStore('snapshot').get('queue'.toJS);
    final done = Completer<String?>();
    transaction.oncomplete = ((web.Event event) {
      done.complete((request.result as JSString?)?.toDart);
    }).toJS;
    transaction.onabort = ((web.Event event) {
      done.completeError(StateError('Cannot read persistent outbox'));
    }).toJS;
    return done.future;
  }

  @override
  Future<bool> compareAndSet(String? expected, String value) async {
    final database = await _open();
    final transaction = database.transaction(
      'snapshot'.toJS,
      'readwrite',
      web.IDBTransactionOptions(durability: 'strict'),
    );
    final store = transaction.objectStore('snapshot');
    final request = store.get('queue'.toJS);
    final done = Completer<bool>();
    var changed = false;
    request.onsuccess = ((web.Event event) {
      if ((request.result as JSString?)?.toDart == expected) {
        store.put(value.toJS, 'queue'.toJS);
        changed = true;
      }
    }).toJS;
    transaction.oncomplete = ((web.Event event) {
      done.complete(changed);
    }).toJS;
    transaction.onabort = ((web.Event event) {
      done.completeError(
        StateError('Outbox transaction failed; message was not accepted'),
      );
    }).toJS;
    return done.future;
  }

  @override
  Future<void> close() async {
    _closed = true;
    _database?.close();
    _database = null;
    final opening = _opening;
    _opening = null;
    if (opening != null && !opening.isCompleted) {
      opening.completeError(StateError('Outbox is closed.'));
    }
  }
}
