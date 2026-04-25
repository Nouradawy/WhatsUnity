enum SyncOpType { create, update, delete, uploadMedia }

SyncOpType syncOpTypeFromString(String raw) {
  switch (raw.toUpperCase()) {
    case 'CREATE':
      return SyncOpType.create;
    case 'UPDATE':
      return SyncOpType.update;
    case 'DELETE':
      return SyncOpType.delete;
    case 'UPLOAD_MEDIA':
      return SyncOpType.uploadMedia;
    default:
      return SyncOpType.update;
  }
}

String syncOpTypeToStorage(SyncOpType op) {
  switch (op) {
    case SyncOpType.create:
      return 'CREATE';
    case SyncOpType.update:
      return 'UPDATE';
    case SyncOpType.delete:
      return 'DELETE';
    case SyncOpType.uploadMedia:
      return 'UPLOAD_MEDIA';
  }
}
