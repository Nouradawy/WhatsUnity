enum SyncJobStatus { pending, processing, completed, deadLetter }

SyncJobStatus syncJobStatusFromString(String? raw) {
  if (raw == null || raw.isEmpty) return SyncJobStatus.pending;
  switch (raw.toLowerCase()) {
    case 'pending':
      return SyncJobStatus.pending;
    case 'processing':
      return SyncJobStatus.processing;
    case 'completed':
      return SyncJobStatus.completed;
    case 'dead_letter':
      return SyncJobStatus.deadLetter;
    default:
      return SyncJobStatus.pending;
  }
}

String syncJobStatusToStorage(SyncJobStatus s) {
  switch (s) {
    case SyncJobStatus.pending:
      return 'pending';
    case SyncJobStatus.processing:
      return 'processing';
    case SyncJobStatus.completed:
      return 'completed';
    case SyncJobStatus.deadLetter:
      return 'dead_letter';
  }
}
