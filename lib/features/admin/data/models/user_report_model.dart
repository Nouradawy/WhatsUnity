import 'package:WhatsUnity/core/sync/sync_metadata.dart';
import 'package:WhatsUnity/core/sync/sync_state.dart';

import '../../domain/entities/user_report.dart';

/// Appwrite `report_user` document (APPWRITE_SCHEMA.md §2.8).
///
/// [id] is the document `\$id` returned by Appwrite (not an application-generated int).
class UserReportModel extends UserReport implements SyncMetadata {
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

  UserReportModel({
    super.id,
    required super.authorId,
    required super.createdAt,
    required super.reportedUserId,
    required super.state,
    required super.description,
    required super.messageId,
    required super.reportedFor,
    super.compoundId,
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

  /// Parses merged document JSON: `\$id` plus camelCase attributes from the schema.
  factory UserReportModel.fromAppwriteJson(Map<String, dynamic> json) {
    final id = json[r'$id']?.toString() ?? json['id']?.toString();
    final createdAt =
        _parseDate(json['createdAt']) ??
        _parseDate(json[r'$createdAt']) ??
        DateTime.now().toUtc();
    final ver = int.tryParse(json['version']?.toString() ?? '') ?? 0;

    return UserReportModel(
      id: id,
      authorId: json['authorId']?.toString() ?? '',
      createdAt: createdAt,
      reportedUserId: json['reportedUserId']?.toString() ?? '',
      state: json['state']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      messageId: json['messageId']?.toString() ?? '',
      reportedFor: json['reportedFor']?.toString() ?? '',
      compoundId: json['compoundId']?.toString(),
      version: ver,
      syncState: SyncState.clean,
      remoteUpdatedAt: _parseDate(json[r'$updatedAt']),
      deletedAt: _parseDate(json['deleted_at']),
    );
  }

  /// `data` map for Appwrite `createDocument` / `updateDocument` (no `\$id` on create).
  Map<String, dynamic> toAppwriteJson() {
    return {
      'authorId': authorId,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'reportedUserId': reportedUserId,
      'state': state,
      'description': description,
      'messageId': messageId,
      'reportedFor': reportedFor,
      if (compoundId != null && compoundId!.isNotEmpty) 'compoundId': compoundId,
      'version': version,
      if (deletedAt != null)
        'deleted_at': deletedAt!.toUtc().toIso8601String(),
    };
  }

  factory UserReportModel.fromJson(Map<String, dynamic> json) =>
      UserReportModel.fromAppwriteJson(json);

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      ...toAppwriteJson(),
    };
  }
}
