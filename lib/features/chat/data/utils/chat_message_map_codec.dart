import 'dart:convert';

import 'package:flutter_chat_core/flutter_chat_core.dart' as types;

/// Maps [types.Message] to a Supabase-shaped [Map] compatible with [MessageModel.fromMap].
class ChatMessageMapCodec {
  ChatMessageMapCodec._();

  static Map<String, dynamic> messageToMap(types.Message msg) {
    final meta = Map<String, dynamic>.from(msg.metadata ?? {});
    final createdAtIso = msg.createdAt?.toUtc().toIso8601String();
    final createdAtMs = msg.createdAt?.toUtc().millisecondsSinceEpoch;

    if (createdAtIso != null && createdAtMs != null) {
      meta['createdAtMs'] = createdAtMs;
    }

    // Preserve the reply-to id in metadata so it survives round-trips through
    // local storage (fromMap reads replyToMessageId from metadata['reply_to']).
    if (msg.replyToMessageId != null) {
      meta['reply_to'] = msg.replyToMessageId;
    }

    return {
      'author_id': msg.authorId,
      'created_at': createdAtIso,
      'created_at_ms': createdAtMs,
      'id': msg.id,
      'metadata': meta,
      'uri': msg is types.FileMessage
          ? msg.source
          : (msg is types.ImageMessage
              ? msg.source
              : (msg is types.AudioMessage ? msg.source : null)),
      'text': msg is types.TextMessage ? msg.text : null,
      'type': meta['type'],
      // Re-expose temporal fields as top-level columns so that _normalizeRow
      // can include them in payload_json and fromMap.containsKey() guards work
      // correctly on every subsequent load from local storage.
      'deleted_at': meta['deletedAt'],
      'sent_at': meta['sentAt'],
      'failed_at': meta['failedAt'],
      'delivered_at': meta['deliveredAt'],
      'updated_at': meta['updatedAt'],
    };
  }

  static int extractCreatedAtMs(Map<String, dynamic> map) {
    dynamic createdAtMsRaw = map['created_at_ms'] ?? map['createdAtMs'];
    final meta = map['metadata'];
    if (createdAtMsRaw == null && meta != null) {
      final m = meta is String ? _tryDecodeMeta(meta) : meta;
      if (m is Map) {
        createdAtMsRaw = m['createdAtMs'];
      }
    }
    if (createdAtMsRaw != null) {
      if (createdAtMsRaw is num) return createdAtMsRaw.toInt();
      if (createdAtMsRaw is String) return int.tryParse(createdAtMsRaw) ?? 0;
    }
    final ca = map['created_at'];
    if (ca is String) {
      try {
        return DateTime.parse(ca).toUtc().millisecondsSinceEpoch;
      } catch (_) {}
    }
    return 0;
  }

  static Map<String, dynamic>? _tryDecodeMeta(String s) {
    try {
      final d = jsonDecode(s);
      if (d is Map) return Map<String, dynamic>.from(d);
    } catch (_) {}
    return null;
  }
}
