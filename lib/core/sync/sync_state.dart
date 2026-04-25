/// Local row lifecycle for offline-first entities (MIGRATION_PLAN §1.2).
enum SyncState {
  /// Matches server (or no pending outbound work).
  clean,

  /// Local changes waiting to be pushed.
  dirty,

  /// Tombstone queued for remote delete.
  pendingDelete,

  /// Push/pull failed after retries; operator may reset.
  failed,
}

SyncState syncStateFromString(String? raw) {
  if (raw == null || raw.isEmpty) return SyncState.clean;
  return SyncState.values.firstWhere(
    (e) => e.name == raw,
    orElse: () => SyncState.clean,
  );
}
