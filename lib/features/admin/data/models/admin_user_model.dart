import 'package:WhatsUnity/core/sync/sync_metadata.dart';
import 'package:WhatsUnity/core/sync/sync_state.dart';

import '../../domain/entities/admin_user.dart';

List<Map<String, dynamic>> _verFilesFrom(dynamic v) {
  if (v == null) return [];
  if (v is List) {
    return v.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
  return [];
}

/// Appwrite `profiles` document (APPWRITE_SCHEMA.md §2.1) narrowed for admin member lists.
///
/// [authorId] equals the document `\$id`, which matches the Appwrite Account user id.
class AdminUserModel extends AdminUser implements SyncMetadata {
  @override
  final int version;

  @override
  final SyncState syncState;

  @override
  final DateTime? localUpdatedAt;

  @override
  final DateTime? remoteUpdatedAt;

  @override
  final DateTime? deletedAt;

  @override
  final String? lastSyncError;

  AdminUserModel({
    required super.authorId,
    required super.phoneNumber,
    required super.updatedAt,
    required super.ownerShipType,
    required super.userState,
    required super.actionTakenBy,
    required super.verFiles,
    this.version = 0,
    this.syncState = SyncState.clean,
    this.localUpdatedAt,
    this.remoteUpdatedAt,
    this.deletedAt,
    this.lastSyncError,
  });

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    final s = v.toString();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s);
  }

  /// Parses merged document JSON: `\$id` is the profile / user id.
  factory AdminUserModel.fromAppwriteJson(Map<String, dynamic> json) {
    final authorId = json[r'$id']?.toString() ?? json['id']?.toString() ?? '';
    final ver = int.tryParse(json['version']?.toString() ?? '') ?? 0;

    return AdminUserModel(
      authorId: authorId,
      phoneNumber: json['phone_number']?.toString() ?? '',
      updatedAt:
          _parseDate(json[r'$updatedAt']) ??
          _parseDate(json['updated_at']) ??
          DateTime.now(),
      ownerShipType: json['owner_type']?.toString() ?? '',
      userState: json['userState']?.toString() ?? '',
      actionTakenBy: json['actionTakenBy']?.toString() ?? '',
      verFiles: _verFilesFrom(json['verFiles']),
      version: ver,
      syncState: SyncState.clean,
      remoteUpdatedAt: _parseDate(json[r'$updatedAt']),
      deletedAt: _parseDate(json['deleted_at']),
    );
  }

  Map<String, dynamic> toAppwriteJson() {
    return {
      'phone_number': phoneNumber,
      'owner_type': ownerShipType,
      'userState': userState,
      'actionTakenBy': actionTakenBy,
      'verFiles': verFiles,
      'version': version,
      if (deletedAt != null)
        'deleted_at': deletedAt!.toUtc().toIso8601String(),
    };
  }

}
