import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Singleton access to the app SQLite database.
class DatabaseHelper {
  DatabaseHelper._();

  static final DatabaseHelper instance = DatabaseHelper._();

  static const _dbName = 'whatsunity.db';
  static const _dbVersion = 5;

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // v2: channel_id is TEXT to support Appwrite string ids (local cache is best-effort).
      await db.execute('DROP INDEX IF EXISTS idx_messages_channel_time');
      await db.execute('DROP TABLE IF EXISTS messages');
      await _createMessagesTable(db);
    }
    if (oldVersion < 4) {
      await _createMaintenanceLocalTables(db);
    }
    // v4 onCreate omitted sync_jobs; v5 ensures table exists. Single run avoids
    // duplicate ALTER noise when both oldVersion < 3 and < 5 applied.
    if (oldVersion < 5) {
      await _migrateV3Sync(db);
    }
  }

  /// MIGRATION_PLAN §1.2–1.3: sync metadata on messages + outbound job queue.
  Future<void> _migrateV3Sync(Database db) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS sync_jobs (
  job_id TEXT PRIMARY KEY NOT NULL,
  entity_type TEXT NOT NULL,
  entity_id TEXT NOT NULL,
  op_type TEXT NOT NULL,
  payload_json TEXT NOT NULL,
  attempts INTEGER NOT NULL DEFAULT 0,
  status TEXT NOT NULL,
  next_retry_at TEXT,
  last_error TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sync_jobs_status_retry ON sync_jobs (status, next_retry_at);',
    );

    Future<void> addColumnIfMissing(String name, String ddl) async {
      final rows = await db.rawQuery('PRAGMA table_info(messages)');
      final exists = rows.any((r) => r['name'] == name);
      if (!exists) await db.execute(ddl);
    }

    await addColumnIfMissing(
      'entity_version',
      'ALTER TABLE messages ADD COLUMN entity_version INTEGER NOT NULL DEFAULT 0;',
    );
    await addColumnIfMissing(
      'sync_state',
      "ALTER TABLE messages ADD COLUMN sync_state TEXT NOT NULL DEFAULT 'clean';",
    );
    await addColumnIfMissing(
      'local_updated_at',
      'ALTER TABLE messages ADD COLUMN local_updated_at TEXT;',
    );
    await addColumnIfMissing(
      'remote_updated_at',
      'ALTER TABLE messages ADD COLUMN remote_updated_at TEXT;',
    );
    await addColumnIfMissing(
      'last_sync_error',
      'ALTER TABLE messages ADD COLUMN last_sync_error TEXT;',
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createMessagesTable(db);
    // onUpgrade is skipped for new DBs — must create queue here too.
    await _migrateV3Sync(db);
    await _createMaintenanceLocalTables(db);
  }

  /// MIGRATION_PLAN §6 — local maintenance cache + [SyncMetadataColumns].
  Future<void> _createMaintenanceLocalTables(Database db) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS local_maintenance_reports (
  id TEXT PRIMARY KEY NOT NULL,
  user_id TEXT NOT NULL,
  compound_id TEXT,
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  category TEXT NOT NULL,
  type TEXT NOT NULL,
  status TEXT,
  report_code TEXT NOT NULL DEFAULT '',
  created_at TEXT NOT NULL,
  updated_at TEXT,
  deleted_at TEXT,
  entity_version INTEGER NOT NULL DEFAULT 0,
  sync_state TEXT NOT NULL DEFAULT 'clean',
  local_updated_at TEXT,
  remote_updated_at TEXT,
  last_sync_error TEXT
);
''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_local_maint_reports_scope ON local_maintenance_reports (compound_id, type, created_at);',
    );
    await db.execute('''
CREATE TABLE IF NOT EXISTS local_maintenance_attachments (
  id TEXT PRIMARY KEY NOT NULL,
  report_id TEXT NOT NULL,
  compound_id TEXT,
  type TEXT NOT NULL,
  source_url TEXT NOT NULL,
  created_at TEXT NOT NULL,
  deleted_at TEXT,
  entity_version INTEGER NOT NULL DEFAULT 0,
  sync_state TEXT NOT NULL DEFAULT 'clean',
  local_updated_at TEXT,
  remote_updated_at TEXT,
  last_sync_error TEXT
);
''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_local_matt_scope ON local_maintenance_attachments (compound_id, type, created_at);',
    );
  }

  Future<void> _createMessagesTable(Database db) async {
    await db.execute('''
CREATE TABLE messages (
  id TEXT PRIMARY KEY NOT NULL,
  channel_id TEXT NOT NULL,
  author_id TEXT NOT NULL,
  content TEXT,
  uri TEXT,
  type TEXT,
  created_at TEXT NOT NULL,
  created_at_ms INTEGER NOT NULL,
  metadata TEXT NOT NULL,
  sent_at TEXT,
  deleted_at TEXT,
  is_synced INTEGER NOT NULL DEFAULT 1,
  entity_version INTEGER NOT NULL DEFAULT 0,
  sync_state TEXT NOT NULL DEFAULT 'clean',
  local_updated_at TEXT,
  remote_updated_at TEXT,
  last_sync_error TEXT,
  payload_json TEXT NOT NULL
);
''');
    await db.execute(
      'CREATE INDEX idx_messages_channel_time ON messages (channel_id, created_at_ms);',
    );
  }

  /// Call from tests or account reset if needed.
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
