import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';

class AppDatabase {
  AppDatabase({QueryExecutor? executor, String fileName = 'localtube_app.db'})
      : _database = _RawDatabaseConnection(
          executor ??
              LazyDatabase(
                () async {
                  final Directory directory =
                      await getApplicationDocumentsDirectory();
                  final File file = File(
                    '${directory.path}${Platform.pathSeparator}$fileName',
                  );
                  return NativeDatabase.createInBackground(file);
                },
              ),
        );

  final DatabaseConnectionUser _database;
  bool _initialized = false;

  bool get isInitialized => _initialized;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    await _database.customStatement(
      '''
      CREATE TABLE IF NOT EXISTS videos_cache (
        section_key TEXT NOT NULL,
        entity_id INTEGER NOT NULL,
        payload_json TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        PRIMARY KEY(section_key, entity_id)
      )
      ''',
    );

    await _database.customStatement(
      '''
      CREATE TABLE IF NOT EXISTS playback_positions (
        video_id INTEGER PRIMARY KEY,
        position_seconds REAL NOT NULL,
        updated_at TEXT NOT NULL
      )
      ''',
    );

    await _database.customStatement(
      '''
      CREATE TABLE IF NOT EXISTS bookmarks (
        bookmark_id INTEGER PRIMARY KEY,
        video_id INTEGER NOT NULL,
        caption TEXT,
        position_seconds REAL NOT NULL,
        updated_at TEXT NOT NULL
      )
      ''',
    );

    await _database.customStatement(
      '''
      CREATE TABLE IF NOT EXISTS downloads (
        video_id INTEGER PRIMARY KEY,
        status TEXT NOT NULL,
        progress REAL NOT NULL DEFAULT 0,
        title TEXT,
        task_id TEXT,
        local_path TEXT,
        remote_url TEXT,
        queued_at TEXT,
        speed_mbps REAL,
        eta_seconds INTEGER,
        updated_at TEXT NOT NULL
      )
      ''',
    );

    await _database.customStatement(
      '''
      CREATE TABLE IF NOT EXISTS video_metadata (
        video_id INTEGER PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        duration_seconds INTEGER,
        season_name TEXT,
        season_id INTEGER,
        thumbnail_local_path TEXT,
        thumbnail_updated_at TEXT,
        updated_at TEXT NOT NULL
      )
      ''',
    );

    // Backward-compatible schema upgrade for existing DB files.
    try {
      await _database.customStatement(
        'ALTER TABLE downloads ADD COLUMN task_id TEXT',
      );
    } catch (_) {}
    try {
      await _database.customStatement(
        'ALTER TABLE downloads ADD COLUMN title TEXT',
      );
    } catch (_) {}
    try {
      await _database.customStatement(
        'ALTER TABLE downloads ADD COLUMN queued_at TEXT',
      );
    } catch (_) {}
    try {
      await _database.customStatement(
        'ALTER TABLE downloads ADD COLUMN speed_mbps REAL',
      );
    } catch (_) {}
    try {
      await _database.customStatement(
        'ALTER TABLE downloads ADD COLUMN eta_seconds INTEGER',
      );
    } catch (_) {}
    try {
      await _database.customStatement(
        '''
        UPDATE downloads
        SET queued_at = COALESCE(NULLIF(queued_at, ''), updated_at)
        WHERE queued_at IS NULL OR queued_at = ''
        ''',
      );
    } catch (_) {}
    try {
      await _database.customStatement(
        'ALTER TABLE video_metadata ADD COLUMN duration_seconds INTEGER',
      );
    } catch (_) {}
    try {
      await _database.customStatement(
        'ALTER TABLE video_metadata ADD COLUMN season_name TEXT',
      );
    } catch (_) {}
    try {
      await _database.customStatement(
        'ALTER TABLE video_metadata ADD COLUMN season_id INTEGER',
      );
    } catch (_) {}
    try {
      await _database.customStatement(
        'ALTER TABLE video_metadata ADD COLUMN thumbnail_local_path TEXT',
      );
    } catch (_) {}
    try {
      await _database.customStatement(
        'ALTER TABLE video_metadata ADD COLUMN thumbnail_updated_at TEXT',
      );
    } catch (_) {}
    try {
      await _database.customStatement(
        'ALTER TABLE video_metadata ADD COLUMN updated_at TEXT',
      );
    } catch (_) {}

    final String defaultMetadataUpdatedAt =
        DateTime.fromMillisecondsSinceEpoch(0).toUtc().toIso8601String();
    try {
      await _database.customStatement(
        '''
        UPDATE video_metadata
        SET updated_at = COALESCE(NULLIF(updated_at, ''), thumbnail_updated_at, ?)
        WHERE updated_at IS NULL OR updated_at = ''
        ''',
        <Object>[defaultMetadataUpdatedAt],
      );
    } catch (_) {}

    await _database.customStatement(
      '''
      CREATE TABLE IF NOT EXISTS sync_outbox (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        operation_type TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        status TEXT NOT NULL,
        attempts INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL
      )
      ''',
    );

    await _database.customStatement(
      '''
      CREATE TABLE IF NOT EXISTS session_meta (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
      ''',
    );

    await _database.customStatement(
      '''
      CREATE INDEX IF NOT EXISTS idx_videos_cache_section_updated
      ON videos_cache(section_key, updated_at DESC)
      ''',
    );
    await _database.customStatement(
      '''
      CREATE INDEX IF NOT EXISTS idx_downloads_updated
      ON downloads(updated_at DESC)
      ''',
    );
    await _database.customStatement(
      '''
      CREATE INDEX IF NOT EXISTS idx_downloads_queued
      ON downloads(queued_at DESC, updated_at DESC)
      ''',
    );
    await _database.customStatement(
      '''
      CREATE INDEX IF NOT EXISTS idx_downloads_task_id
      ON downloads(task_id)
      ''',
    );
    await _database.customStatement(
      '''
      CREATE INDEX IF NOT EXISTS idx_video_metadata_updated
      ON video_metadata(updated_at DESC)
      ''',
    );

    _initialized = true;
  }

  Future<void> execute(
    String sql, {
    List<Object?> variables = const <Object?>[],
  }) {
    return _database.customStatement(sql, variables);
  }

  Future<List<Map<String, Object?>>> query(
    String sql, {
    List<Object?> variables = const <Object?>[],
  }) async {
    final List<Variable<Object>> driftVariables =
        variables.map(_toVariable).toList(growable: false);
    final List<QueryRow> rows = await _database
        .customSelect(
          sql,
          variables: driftVariables,
        )
        .get();
    return rows.map((QueryRow row) => row.data).toList(growable: false);
  }

  Variable<Object> _toVariable(Object? value) {
    if (value is int) {
      return Variable<int>(value) as Variable<Object>;
    }
    if (value is double) {
      return Variable<double>(value) as Variable<Object>;
    }
    if (value is bool) {
      return Variable<bool>(value) as Variable<Object>;
    }
    return Variable<String>(value?.toString() ?? '') as Variable<Object>;
  }

  Future<void> close() {
    return _database.close();
  }
}

class _RawDatabaseConnection extends DatabaseConnectionUser {
  _RawDatabaseConnection(super.executor) {
    _attachedDatabase = _DatabaseStub.connect(connection);
  }

  late final GeneratedDatabase _attachedDatabase;

  @override
  GeneratedDatabase get attachedDatabase => _attachedDatabase;
}

class _DatabaseStub extends GeneratedDatabase {
  _DatabaseStub.connect(super.connection) : super.connect();

  @override
  int get schemaVersion => 1;

  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      const <TableInfo<Table, Object?>>[];
}
