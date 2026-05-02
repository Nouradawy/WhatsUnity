import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common/sqlite_api.dart';
import 'database_open_delegate.dart';

/// Singleton access to the app SQLite database.
class DatabaseHelper {
  DatabaseHelper._();

  static final DatabaseHelper instance = DatabaseHelper._();

  static const _dbName = 'whatsunity.db';
  static const _dbVersion = 8;

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final String path;
    if (kIsWeb) {
      // Web/PWA: persisted in IndexedDB via sqflite_common_ffi_web.
      path = _dbName;
    } else {
      final dir = await getApplicationDocumentsDirectory();
      path = p.join(dir.path, _dbName);
    }
    debugPrint('[DB] Opening database at $path');
    return openPlatformDatabase(
      path: path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    debugPrint('[DB] Upgrading database from $oldVersion to $newVersion');
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
    if (oldVersion < 6) {
      await _createSessionsTable(db);
    }
    if (oldVersion < 7) {
      await _migrateSessionsRoleIdToText(db);
    }
    if (oldVersion < 8) {
      await _createMembersTable(db);
    }
    debugPrint('[DB] Upgrade complete');
  }

  /// MIGRATION_PLAN §1.2–1.3: sync metadata on messages + outbound job queue.
  Future<void> _migrateV3Sync(Database db) async {
    debugPrint('[DB] Migrating to V3 Sync...');
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
      if (!exists) {
        debugPrint('[DB] Adding column $name to messages');
        await db.execute(ddl);
      }
    }
    // ...

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
    debugPrint('[DB] Creating database version $version');
    await _createMessagesTable(db);
    // onUpgrade is skipped for new DBs — must create queue here too.
    await _migrateV3Sync(db);
    await _createMaintenanceLocalTables(db);
    await _createSessionsTable(db);
    await _createMembersTable(db);
    debugPrint('[DB] Creation complete');
  }

  /// IMPROVE_IMPLEMENTATION.md: local session cache for robust offline restoration.
  Future<void> _createSessionsTable(Database db) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS sessions (
  user_id TEXT PRIMARY KEY NOT NULL,
  email TEXT,
  user_metadata_json TEXT,
  selected_compound_id TEXT,
  my_compounds_json TEXT,
  role_id TEXT,
  updated_at TEXT NOT NULL
);
''');
  }

  Future<void> _migrateSessionsRoleIdToText(Database db) async {
    final cols = await db.rawQuery('PRAGMA table_info(sessions)');
    if (cols.isEmpty) {
      await _createSessionsTable(db);
      return;
    }

    final roleCol = cols.firstWhere(
      (c) => (c['name']?.toString() ?? '') == 'role_id',
      orElse: () => <String, Object?>{},
    );
    final declaredType = (roleCol['type']?.toString() ?? '').toUpperCase();
    if (declaredType == 'TEXT') return;

    await db.transaction((txn) async {
      await txn.execute('''
CREATE TABLE IF NOT EXISTS sessions_new (
  user_id TEXT PRIMARY KEY NOT NULL,
  email TEXT,
  user_metadata_json TEXT,
  selected_compound_id TEXT,
  my_compounds_json TEXT,
  role_id TEXT,
  updated_at TEXT NOT NULL
);
''');
      await txn.execute('''
INSERT OR REPLACE INTO sessions_new (
  user_id,
  email,
  user_metadata_json,
  selected_compound_id,
  my_compounds_json,
  role_id,
  updated_at
)
SELECT
  user_id,
  email,
  user_metadata_json,
  selected_compound_id,
  my_compounds_json,
  CASE
    WHEN role_id IS NULL THEN NULL
    ELSE CAST(role_id AS TEXT)
  END,
  updated_at
FROM sessions;
''');
      await txn.execute('DROP TABLE sessions;');
      await txn.execute('ALTER TABLE sessions_new RENAME TO sessions;');
    });
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

  /// NEW: Local cache for compound members (profiles + apartment info).
  Future<void> _createMembersTable(Database db) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS members (
  id TEXT PRIMARY KEY NOT NULL,
  compound_id TEXT NOT NULL,
  display_name TEXT NOT NULL,
  full_name TEXT,
  avatar_url TEXT,
  building_num TEXT,
  apartment_num TEXT,
  phone_number TEXT,
  owner_type TEXT,
  user_state TEXT,
  updated_at TEXT NOT NULL
);
''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_members_compound ON members (compound_id);',
    );

    // Track last sync per compound to allow delta-syncing.
    await db.execute('''
CREATE TABLE IF NOT EXISTS member_sync_metadata (
  compound_id TEXT PRIMARY KEY NOT NULL,
  last_sync_timestamp TEXT NOT NULL
);
''');
  }

  /// Call from tests or account reset if needed.
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
