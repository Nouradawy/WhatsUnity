import 'dart:convert';

import 'package:flutter_chat_core/flutter_chat_core.dart' as types;

import '../../../../core/sync/sync_metadata.dart';
import '../../../../core/sync/sync_state.dart';

/// Appwrite-first message row model for `messages` (APPWRITE_SCHEMA.md §2.9).
///
/// IDs are always strings:
/// - [id] is message document `$id`
/// - [channelId] is `channels` document `$id`
/// - [authorId] is `profiles` / account user `$id`
class MessageModel with SyncMetadata {
  MessageModel({
    required this.id,
    required this.authorId,
    required this.channelId,
    this.text,
    this.uri,
    this.type,
    this.sentAt,
    required this.metadata,
    this.replyTo,
    this.createdAt,
    @override this.deletedAt,
    @override this.version = 0,
    @override this.syncState = SyncState.clean,
    @override this.localUpdatedAt,
    @override this.remoteUpdatedAt,
    @override this.lastSyncError,
  });

  final String id;
  final String authorId;
  final String channelId;
  final String? text;
  final String? uri;
  final String? type;
  final DateTime? sentAt;
  final Map<String, dynamic> metadata;
  final String? replyTo;
  final DateTime? createdAt;

  @override
  final DateTime? deletedAt;
  @override
  final int version;
  @override
  final SyncState syncState;
  @override
  final DateTime? localUpdatedAt;
  @override
  final DateTime? remoteUpdatedAt;
  @override
  final String? lastSyncError;

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    final raw = v.toString();
    if (raw.isEmpty) return null;
    final tzRegex = RegExp(r'(Z|[+\-]\d{2}:\d{2})$');
    final normalized = tzRegex.hasMatch(raw) ? raw : '${raw}Z';
    return DateTime.tryParse(normalized)?.toLocal();
  }

  static int? _parseMs(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  static Map<String, dynamic> normalizeMeta(dynamic meta) {
    if (meta == null) return <String, dynamic>{};
    if (meta is Map) return Map<String, dynamic>.from(meta);
    if (meta is String) {
      try {
        final decoded = jsonDecode(meta);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return <String, dynamic>{};
  }

  /// Strict Appwrite message map parser using schema keys:
  /// `author_id`, `channel_id`, `text`, `uri`, `type`, `sent_at`, `metadata`,
  /// `reply_to`, `deleted_at`, `version`, and document `$id`.
  factory MessageModel.fromAppwriteJson(Map<String, dynamic> json) {
    final metadata = normalizeMeta(json['metadata']);
    DateTime? createdAt = _parseDate(json[r'$createdAt']) ?? _parseDate(json['created_at']);
    final createdAtMsRaw =
        json['created_at_ms'] ?? json['createdAtMs'] ?? metadata['createdAtMs'];
    final createdAtMs = _parseMs(createdAtMsRaw);
    if (createdAtMs != null) {
      createdAt = DateTime.fromMillisecondsSinceEpoch(
        createdAtMs,
        isUtc: true,
      ).toLocal();
    }

    final parsedVersion = int.tryParse(
          json['version']?.toString() ??
              json[SyncMetadataColumns.version]?.toString() ??
              '',
        ) ??
        0;
    final parsedSyncState = syncStateFromString(
      json[SyncMetadataColumns.syncState]?.toString(),
    );

    return MessageModel(
      id: (json[r'$id'] ?? json['id'] ?? '').toString(),
      authorId: (json['author_id'] ?? '').toString(),
      channelId: (json['channel_id'] ?? '').toString(),
      text: json['text']?.toString(),
      uri: json['uri']?.toString(),
      type: json['type']?.toString(),
      sentAt: _parseDate(json['sent_at']),
      metadata: metadata,
      replyTo: json['reply_to']?.toString(),
      createdAt: createdAt,
      deletedAt: _parseDate(json['deleted_at']),
      version: parsedVersion,
      syncState: parsedSyncState,
      localUpdatedAt: _parseDate(json[SyncMetadataColumns.localUpdatedAt]),
      remoteUpdatedAt: _parseDate(
        json[SyncMetadataColumns.remoteUpdatedAt] ?? json[r'$updatedAt'],
      ),
      lastSyncError: json[SyncMetadataColumns.lastSyncError]?.toString(),
    );
  }

  /// Builds Appwrite data payload for create/update.
  Map<String, dynamic> toAppwriteJson() {
    return {
      'author_id': authorId,
      'channel_id': channelId,
      if (text != null) 'text': text,
      if (uri != null) 'uri': uri,
      if (type != null) 'type': type,
      if (sentAt != null) 'sent_at': sentAt!.toUtc().toIso8601String(),
      'metadata': jsonEncode(metadata),
      if (replyTo != null && replyTo!.isNotEmpty) 'reply_to': replyTo,
      if (deletedAt != null) 'deleted_at': deletedAt!.toUtc().toIso8601String(),
      'version': version,
    };
  }

  /// Compatibility wrapper for existing call sites.
  static types.Message fromMap(Map<String, dynamic> map) =>
      MessageModel.fromAppwriteJson(map).toChatMessage();

  types.Message toChatMessage() {
    final metadataOut = Map<String, dynamic>.from(metadata);
    final failedAt = _parseDate(metadataOut['failedAt']);
    final sentAtParsed = sentAt ?? _parseDate(metadataOut['sentAt']);
    final deliveredAt = _parseDate(metadataOut['deliveredAt']);
    final updatedAt = _parseDate(metadataOut['updatedAt']);
    final isSeen = metadataOut['isSeen'] == true;

    if (deletedAt != null) metadataOut['deletedAt'] = deletedAt!.toIso8601String();
    if (failedAt != null) metadataOut['failedAt'] = failedAt.toIso8601String();
    if (sentAtParsed != null) metadataOut['sentAt'] = sentAtParsed.toIso8601String();
    if (deliveredAt != null) metadataOut['deliveredAt'] = deliveredAt.toIso8601String();
    if (updatedAt != null) metadataOut['updatedAt'] = updatedAt.toIso8601String();
    metadataOut['isSeen'] = isSeen;
    if (createdAt != null) {
      metadataOut['createdAtMs'] = createdAt!.toUtc().millisecondsSinceEpoch;
    }

    final messageType = metadataOut['type'] ?? type;
    const deletedUserId = 'deleted_user';
    final safeAuthor = authorId.isNotEmpty ? authorId : deletedUserId;

    switch (messageType) {
      case 'image':
        return types.ImageMessage(
          createdAt: createdAt,
          id: id,
          text: metadataOut['name'] ?? 'image',
          authorId: safeAuthor,
          size: metadataOut['size'] ?? 0,
          height: metadataOut['height']?.toDouble(),
          width: metadataOut['width']?.toDouble(),
          source: uri ?? '',
          metadata: metadataOut,
          replyToMessageId: metadataOut['reply_to'] ?? replyTo,
        );
      case 'file':
        return types.FileMessage(
          createdAt: createdAt,
          id: id,
          authorId: safeAuthor,
          name: metadataOut['name'] ?? 'File',
          size: metadataOut['size'] ?? 0,
          mimeType: metadataOut['mimeType'],
          source: uri ?? '',
          metadata: metadataOut,
          replyToMessageId: metadataOut['reply_to'] ?? replyTo,
        );
      case 'audio':
        final durationString = metadataOut['duration'] ?? '00:00';
        final parts = durationString.toString().split(':');
        final duration = Duration(
          minutes: int.tryParse(parts.isNotEmpty ? parts[0] : '0') ?? 0,
          seconds: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
        );
        return types.AudioMessage(
          createdAt: createdAt,
          id: id,
          authorId: safeAuthor,
          size: metadataOut['size'] ?? 0,
          source: uri ?? '',
          duration: duration,
          metadata: metadataOut,
          replyToMessageId: metadataOut['reply_to'] ?? replyTo,
        );
      default:
        return types.TextMessage(
          createdAt: createdAt,
          id: id,
          authorId: safeAuthor,
          text: text ?? '',
          metadata: metadataOut,
          replyToMessageId: metadataOut['reply_to'] ?? replyTo,
          deliveredAt: deliveredAt,
        );
    }
  }

  /// `channel_id` from a messages row (always Appwrite channel document `$id`).
  static String channelIdFromRow(Map<String, dynamic> map) {
    final v = map['channel_id'];
    if (v == null) return '';
    return v.toString();
  }
}
