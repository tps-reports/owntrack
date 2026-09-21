import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:owntrack/data/datasources/outbox/outbox_store.dart';

OutboxStore createOutboxStore() => SqliteOutboxStore(
  LazyDatabase(() async {
    final directory = await getApplicationSupportDirectory();
    await directory.create(recursive: true);
    return NativeDatabase.createInBackground(
      File(path.join(directory.path, 'owntrack-outbox.sqlite')),
    );
  }),
);

class _OutboxDatabase extends GeneratedDatabase {
  _OutboxDatabase(super.executor);
  @override
  int get schemaVersion => 1;
  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => const [];
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (_) => customStatement(
      'CREATE TABLE outbox_snapshot (id INTEGER PRIMARY KEY CHECK (id = 1), value TEXT NOT NULL)',
    ),
  );
}

/// SQLite transactions protect both the snapshot and migration marker. The
/// constructor accepts a real executor for file-backed restart/fault tests.
class SqliteOutboxStore implements OutboxStore {
  SqliteOutboxStore(QueryExecutor executor)
    : _database = _OutboxDatabase(executor);
  final _OutboxDatabase _database;

  @override
  Future<String?> read() async {
    final row = await _database
        .customSelect('SELECT value FROM outbox_snapshot WHERE id = 1')
        .getSingleOrNull();
    return row?.read<String>('value');
  }

  @override
  Future<bool> compareAndSet(String? expected, String value) =>
      _database.transaction(() async {
        if (expected == null) {
          final changed = await _database.customUpdate(
            'INSERT OR IGNORE INTO outbox_snapshot (id, value) VALUES (1, ?)',
            variables: [Variable<String>(value)],
          );
          return changed == 1;
        }
        final changed = await _database.customUpdate(
          'UPDATE outbox_snapshot SET value = ? WHERE id = 1 AND value = ?',
          variables: [Variable<String>(value), Variable<String>(expected)],
        );
        return changed == 1;
      });

  @override
  Future<void> close() => _database.close();
}
