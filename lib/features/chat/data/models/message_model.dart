import 'dart:convert';

import 'package:flutter_chat_core/flutter_chat_core.dart' as types;

class MessageModel {
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

  static types.Message fromMap(Map<String, dynamic> map) {
    DateTime? parseDate(String? dateStr) {
      if (dateStr == null) return null;
      final tzRegex = RegExp(r'(Z|[+\-]\d{2}:\d{2})$');
      DateTime parsed;
      if (tzRegex.hasMatch(dateStr)) {
        parsed = DateTime.parse(dateStr);
      } else {
        parsed = DateTime.parse('${dateStr}Z');
      }
      return parsed.toLocal();
    }

    DateTime? createdAt;
    final createdAtMsRaw = map['created_at_ms'] ?? map['createdAtMs'] ?? map['metadata']?['createdAtMs'];
    if (createdAtMsRaw != null) {
      int? ms;
      if (createdAtMsRaw is String) {
        ms = int.tryParse(createdAtMsRaw);
      } else if (createdAtMsRaw is num) {
        ms = createdAtMsRaw.toInt();
      }
      if (ms != null) {
        createdAt = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();
      }
    }

    createdAt ??= parseDate(map['created_at']);
    final deletedAt = parseDate(map['deleted_at']);
    final failedAt = parseDate(map['failed_at']);
    final bool isSeen = map['isSeen'] ?? false;
    final sentAt = parseDate(map['sent_at']);
    final deliveredAt = parseDate(map['delivered_at']);
    final updatedAt = parseDate(map['updated_at']);

    final metadata = normalizeMeta(map['metadata']);

    // Only promote top-level column values into metadata when the key is
    // explicitly present in the incoming map.  If the key is absent (e.g. when
    // the map was produced by ChatMessageMapCodec.messageToMap, which does not
    // include every column), we must NOT overwrite the existing metadata value
    // with null — that would silently erase soft-delete markers, reply links,
    // and other data that survived the previous round-trip through storage.
    if (map.containsKey('deleted_at')) {
      metadata['deletedAt'] = deletedAt?.toIso8601String();
    }
    if (map.containsKey('failed_at')) {
      metadata['failedAt'] = failedAt?.toIso8601String();
    }
    if (map.containsKey('sent_at')) {
      metadata['sentAt'] = sentAt?.toIso8601String();
    }
    if (map.containsKey('delivered_at')) {
      metadata['deliveredAt'] = deliveredAt?.toIso8601String();
    }
    if (map.containsKey('updated_at')) {
      metadata['updatedAt'] = updatedAt?.toIso8601String();
    }
    // isSeen is a boolean flag; always set it (defaults to false when missing).
    metadata['isSeen'] = isSeen;

    if (createdAt != null) {
      metadata['createdAtMs'] = createdAt.toUtc().millisecondsSinceEpoch;
    }

    final messageType = metadata['type'] ?? map['type'];
    const String deletedUserId = 'deleted_user';

    switch (messageType) {
      case 'image':
        return types.ImageMessage(
          createdAt: createdAt,
          id: map['id'],
          text: metadata['name'] ?? 'image',
          authorId: map['author_id'] ?? deletedUserId,
          size: metadata['size'] ?? 0,
          height: metadata['height']?.toDouble(),
          width: metadata['width']?.toDouble(),
          source: map['uri'],
          metadata: metadata,
          replyToMessageId: metadata['reply_to'],
        );
      case 'file':
        return types.FileMessage(
          createdAt: createdAt,
          id: map['id'],
          authorId: map['author_id'] ?? deletedUserId,
          name: metadata['name'] ?? 'File',
          size: metadata['size'] ?? 0,
          mimeType: metadata['mimeType'],
          source: map['uri'],
          metadata: metadata,
          replyToMessageId: metadata['reply_to'],
        );
      case 'audio':
        final durationString = metadata['duration'] ?? '00:00';
        final parts = durationString.split(':');
        final duration = Duration(
          minutes: int.tryParse(parts[0]) ?? 0,
          seconds: int.tryParse(parts[1]) ?? 0,
        );
        return types.AudioMessage(
          createdAt: createdAt,
          id: map['id'],
          authorId: map['author_id'] ?? deletedUserId,
          size: metadata['size'] ?? 0,
          source: map['uri'],
          duration: duration,
          metadata: metadata,
          replyToMessageId: metadata['reply_to'],
        );
      default:
        return types.TextMessage(
          createdAt: createdAt,
          id: map['id'],
          authorId: map['author_id'] ?? deletedUserId,
          text: map['text'] ?? '',
          metadata: metadata,
          replyToMessageId: metadata['reply_to'],
          deliveredAt: deliveredAt,
        );
    }
  }

  /// `channel_id` from a messages row (legacy int or Appwrite string).
  static String channelIdFromRow(Map<String, dynamic> map) {
    final v = map['channel_id'];
    if (v == null) return '';
    return v.toString();
  }
}
