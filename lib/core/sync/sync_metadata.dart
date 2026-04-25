import 'sync_state.dart';

/// Column names shared by local `sqflite` tables (MIGRATION_PLAN §1.2).
abstract final class SyncMetadataColumns {
  static const version = 'entity_version';
  static const syncState = 'sync_state';
  static const localUpdatedAt = 'local_updated_at';
  static const remoteUpdatedAt = 'remote_updated_at';
  static const deletedAt = 'deleted_at';
  static const lastSyncError = 'last_sync_error';
}

/// Mixin for Dart domain / row DTOs that mirror local sync metadata.
mixin SyncMetadata {
  int get version;
  SyncState get syncState;
  DateTime? get localUpdatedAt;
  DateTime? get remoteUpdatedAt;
  DateTime? get deletedAt;
  String? get lastSyncError;
}

/// Helpers for reading/writing sync fields on `Map<String, dynamic>` rows.
extension SyncMetadataMap on Map<String, dynamic> {
  int get syncVersion =>
      int.tryParse(this[SyncMetadataColumns.version]?.toString() ?? '') ?? 0;

  SyncState get syncStateParsed =>
      syncStateFromString(this[SyncMetadataColumns.syncState]?.toString());

  DateTime? parseSyncDate(String key) {
    final s = this[key]?.toString();
    if (s == null || s.isEmpty) return null;
    return DateTime.tryParse(s);
  }
}

bool remoteWinsLastWrite({
  required int remoteVersion,
  required int localVersion,
}) {
  return remoteVersion >= localVersion;
}
