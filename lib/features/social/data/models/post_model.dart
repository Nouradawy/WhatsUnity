import 'dart:convert';

import 'package:WhatsUnity/core/sync/sync_metadata.dart';
import 'package:WhatsUnity/core/sync/sync_state.dart';
import '../../domain/entities/post.dart';

/// Appwrite `posts` row (APPWRITE_SCHEMA.md §2.14).
///
/// [id] is the document `\$id` — the canonical string primary key for the post.
class PostModel extends Post implements SyncMetadata {
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

  PostModel({
    required super.id,
    required super.compoundId,
    required super.authorId,
    required super.postHead,
    required super.sourceUrl,
    required super.getCalls,
    required super.comments,
    super.createdAt,
    this.version = 0,
    this.syncState = SyncState.clean,
    this.localUpdatedAt,
    this.remoteUpdatedAt,
    this.deletedAt,
    this.lastSyncError,
  });

  static List<Map<String, dynamic>> _decodeJsonMapList(dynamic value) {
    if (value == null) return [];
    if (value is String) {
      if (value.isEmpty) return [];
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) {
          return decoded
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        }
      } catch (_) {}
      return [];
    }
    if (value is List) {
      return value
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    return [];
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    final s = v.toString();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s)?.toLocal();
  }

  /// Parses a map merged from an Appwrite document: `\$id`, `\$createdAt`, `\$updatedAt`,
  /// plus attribute keys exactly as in the schema (`compound_id`, `author_id`, …).
  ///
  /// The post [id] is always the document `\$id` (same string used as the document id in API calls).
  factory PostModel.fromAppwriteJson(Map<String, dynamic> json) {
    final id = json[r'$id']?.toString() ?? json['id']?.toString() ?? '';
    final compoundId = json['compound_id']?.toString() ?? '';
    final authorId = json['author_id']?.toString() ?? '';
    final postHead = json['post_head']?.toString() ?? '';
    final sourceUrl = _decodeJsonMapList(json['source_url']);
    final comments = _decodeJsonMapList(json['Comments']);
    final getCalls =
        json['getCalls'] == true || json['getCalls'] == 1 || json['getCalls'] == 'true';
    final createdAt =
        _parseDate(json[r'$createdAt']) ?? _parseDate(json['created_at']);
    final deletedAt = _parseDate(json['deleted_at']);
    final ver = int.tryParse(json['version']?.toString() ?? '') ?? 0;

    return PostModel(
      id: id,
      compoundId: compoundId,
      authorId: authorId,
      postHead: postHead,
      sourceUrl: sourceUrl,
      getCalls: getCalls,
      comments: comments,
      createdAt: createdAt,
      version: ver,
      syncState: SyncState.clean,
      remoteUpdatedAt: _parseDate(json[r'$updatedAt']),
      deletedAt: deletedAt,
    );
  }

  /// `data` payload for Appwrite create/update (no `\$id`; pass [id] as `documentId` separately).
  Map<String, dynamic> toAppwriteJson() {
    return {
      'compound_id': compoundId,
      'author_id': authorId,
      'post_head': postHead,
      'source_url': jsonEncode(sourceUrl),
      'getCalls': getCalls,
      'Comments': jsonEncode(comments),
      'version': version,
      if (deletedAt != null)
        'deleted_at': deletedAt!.toUtc().toIso8601String(),
    };
  }

  factory PostModel.fromJson(Map<String, dynamic> json) =>
      PostModel.fromAppwriteJson(json);

  Map<String, dynamic> toJson() {
    return {
      r'$id': id,
      'id': id,
      ...toAppwriteJson(),
      'created_at': createdAt?.toIso8601String(),
    };
  }
}
