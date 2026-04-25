import 'sync_metadata.dart';

/// Last-write-wins using monotonic [entity_version] / remote `version` (APPWRITE_SCHEMA).
bool shouldApplyRemoteToLocal({
  required Map<String, dynamic>? localRow,
  required Map<String, dynamic> remoteRow,
}) {
  final remoteVer = int.tryParse(remoteRow['version']?.toString() ?? '') ?? 0;
  if (localRow == null) return true;
  final localVer =
      int.tryParse(localRow[SyncMetadataColumns.version]?.toString() ?? '') ??
      0;
  return remoteWinsLastWrite(remoteVersion: remoteVer, localVersion: localVer);
}
