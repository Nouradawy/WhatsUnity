import 'dart:convert';

import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as aw_models;
import 'package:WhatsUnity/core/config/appwrite.dart';
import 'package:WhatsUnity/features/chat/data/datasources/chat_realtime_handle.dart';
import 'package:uuid/uuid.dart';

// APPWRITE_SCHEMA.md §2.9 / §2.10 — tools/provision_spec.json
const String _kMessagesCollectionId = 'messages';
const String _kMessageReceiptsCollectionId = 'message_receipts';
const String _kProfilesCollectionId = 'profiles';

String _jsonEncodeMap(Map<String, dynamic> m) => jsonEncode(m);

Map<String, dynamic> _metadataFromField(dynamic v) {
  if (v == null) return {};
  if (v is String) {
    if (v.isEmpty) return {};
    try {
      final d = jsonDecode(v);
      if (d is Map) return Map<String, dynamic>.from(d);
    } catch (_) {}
    return {};
  }
  if (v is Map) return Map<String, dynamic>.from(v);
  return {};
}

Map<String, dynamic> _documentToMessageRow(aw_models.Document doc) {
  final d = doc.data;
  return {
    'id': doc.$id,
    'author_id': d['author_id']?.toString() ?? '',
    'channel_id': d['channel_id']?.toString() ?? '',
    'text': d['text']?.toString(),
    'uri': d['uri']?.toString(),
    'type': d['type']?.toString(),
    'metadata': _metadataFromField(d['metadata']),
    'reply_to': d['reply_to']?.toString(),
    'created_at': doc.$createdAt,
    'sent_at': d['sent_at']?.toString(),
    'deleted_at': d['deleted_at']?.toString(),
  };
}

Map<String, dynamic> _mapPayloadToMessageRow(Map<String, dynamic> raw) {
  // Realtime and REST both may match [Document] shape; fallback to ad-hoc merge.
  try {
    final doc = aw_models.Document.fromMap(raw);
    if (doc.$id.isNotEmpty) {
      return _documentToMessageRow(doc);
    }
  } catch (_) {}
  // Plain data map
  if (raw.containsKey(r'$id') && (raw['data'] as Map?) != null) {
    final data = Map<String, dynamic>.from(raw['data'] as Map);
    return {
      'id': raw[r'$id']?.toString() ?? '',
      'author_id': data['author_id']?.toString() ?? '',
      'channel_id': data['channel_id']?.toString() ?? '',
      'text': data['text']?.toString(),
      'uri': data['uri']?.toString(),
      'type': data['type']?.toString(),
      'metadata': _metadataFromField(data['metadata']),
      'reply_to': data['reply_to']?.toString(),
      'created_at': raw[r'$createdAt']?.toString(),
      'sent_at': data['sent_at']?.toString(),
      'deleted_at': data['deleted_at']?.toString(),
    };
  }
  // Only $id (delete tombstone) or flat data
  final m = <String, dynamic>{};
  m['id'] = raw[r'$id']?.toString() ?? raw['id']?.toString() ?? '';
  m['author_id'] = raw['author_id']?.toString() ?? '';
  m['channel_id'] = raw['channel_id']?.toString() ?? '';
  m['text'] = raw['text']?.toString();
  m['uri'] = raw['uri']?.toString();
  m['type'] = raw['type']?.toString();
  m['metadata'] = _metadataFromField(raw['metadata']);
  m['reply_to'] = raw['reply_to']?.toString();
  m['created_at'] = raw[r'$createdAt']?.toString() ?? raw['created_at']?.toString();
  m['sent_at'] = raw['sent_at']?.toString();
  m['deleted_at'] = raw['deleted_at']?.toString();
  return m;
}

String _eventSuffix(List<String> events) {
  for (final e in events) {
    final i = e.lastIndexOf('.');
    if (i != -1 && i < e.length - 1) {
      return e.substring(i + 1);
    }
  }
  return '';
}

abstract class ChatRemoteDataSource {
  Future<List<Map<String, dynamic>>> fetchMessages({
    required String channelId,
    required String currentUserId,
    required int pageSize,
    required int pageNum,
  });

  Future<void> sendTextMessage({
    required String text,
    required String channelId,
    required String userId,
    required String nowIso,
    required int nowMs,
    String? repliedMessageId,
  });

  Future<void> sendFileMessage({
    required String uri,
    required String name,
    required int size,
    required String channelId,
    required String userId,
    required String type,
    required String nowIso,
    required int nowMs,
    Map<String, dynamic>? additionalMetadata,
  });

  Future<void> sendVoiceNote({
    required String uri,
    required Duration duration,
    required List<double> waveform,
    required String channelId,
    required String userId,
    required String nowIso,
    required int nowMs,
  });

  Future<void> markMessageAsSeen(
    String messageId,
    String userId,
    String nowIso,
  );

  Future<void> deleteMessage(
    String messageId,
    String authorId,
    String currentUserId,
    String nowIso,
  );

  /// Persists [metadata] JSON to the message document (e.g. reactions).
  Future<void> updateMessageMetadata(
    String messageId,
    Map<String, dynamic> metadata,
  );

  /// Single message row (same shape as [fetchMessages]) for metadata refresh.
  Future<Map<String, dynamic>> fetchMessageRow(String messageId);

  Future<Map<String, dynamic>> resolveUser(String id);

  ChatRealtimeHandle subscribeToChannel({
    required String channelId,
    required void Function(Map<String, dynamic> payload) onInsert,
    required void Function(Map<String, dynamic> payload) onUpdate,
    void Function(Map<String, dynamic> payload)? onDelete,
  });
}

class ChatRemoteDataSourceImpl implements ChatRemoteDataSource {
  ChatRemoteDataSourceImpl({
    required Databases databases,
    required Realtime realtime,
  })  : _databases = databases,
        _realtime = realtime;

  final Databases _databases;
  final Realtime _realtime;

  @override
  Future<List<Map<String, dynamic>>> fetchMessages({
    required String channelId,
    required String currentUserId,
    required int pageSize,
    required int pageNum,
  }) async {
    // ignore: unused_local_variable — reserved for future permission-filtered fetches (legacy RPC)
    final _ = currentUserId;

    final limit = pageSize < 1 ? 1 : pageSize;
    final list = await _databases.listDocuments(
      databaseId: appwriteDatabaseId,
      collectionId: _kMessagesCollectionId,
      queries: [
        Query.equal('channel_id', channelId),
        Query.isNull('deleted_at'),
        Query.orderDesc(r'$createdAt'),
        Query.limit(limit),
        if (pageNum > 0) Query.offset(pageNum * pageSize),
      ],
    );
    return list.documents.map(_documentToMessageRow).toList();
  }

  @override
  Future<void> sendTextMessage({
    required String text,
    required String channelId,
    required String userId,
    required String nowIso,
    required int nowMs,
    String? repliedMessageId,
  }) async {
    final metadata = <String, dynamic>{
      'type': 'text',
      'createdAtMs': nowMs,
      if (repliedMessageId != null) 'reply_to': repliedMessageId,
    };
    final docId = ID.unique();
    await _databases.createDocument(
      databaseId: appwriteDatabaseId,
      collectionId: _kMessagesCollectionId,
      documentId: docId,
      data: {
        'author_id': userId,
        'channel_id': channelId,
        'text': text,
        'sent_at': nowIso,
        'metadata': _jsonEncodeMap(metadata),
        'reply_to': repliedMessageId,
        'version': 0,
      },
    );
  }

  @override
  Future<void> sendFileMessage({
    required String uri,
    required String name,
    required int size,
    required String channelId,
    required String userId,
    required String type,
    required String nowIso,
    required int nowMs,
    Map<String, dynamic>? additionalMetadata,
  }) async {
    final metadata = <String, dynamic>{
      'type': type,
      'name': name,
      'size': size,
      'createdAtMs': nowMs,
      if (additionalMetadata != null) ...additionalMetadata,
    };
    await _databases.createDocument(
      databaseId: appwriteDatabaseId,
      collectionId: _kMessagesCollectionId,
      documentId: ID.unique(),
      data: {
        'author_id': userId,
        'channel_id': channelId,
        'uri': uri,
        'type': type,
        'sent_at': nowIso,
        'metadata': _jsonEncodeMap(metadata),
        'version': 0,
      },
    );
  }

  @override
  Future<void> sendVoiceNote({
    required String uri,
    required Duration duration,
    required List<double> waveform,
    required String channelId,
    required String userId,
    required String nowIso,
    required int nowMs,
  }) async {
    final id = const Uuid().v4();
    final metadata = <String, dynamic>{
      'type': 'audio',
      'name': 'voice_note_${id.substring(0, 8)}.m4a',
      'createdAtMs': nowMs,
      'duration':
          '${duration.inMinutes.remainder(60).toString().padLeft(2, '0')}:${duration.inSeconds.remainder(60).toString().padLeft(2, '0')}',
      'waveform': waveform,
      'status': 'processing',
    };
    await _databases.createDocument(
      databaseId: appwriteDatabaseId,
      collectionId: _kMessagesCollectionId,
      documentId: ID.unique(),
      data: {
        'author_id': userId,
        'channel_id': channelId,
        'uri': uri,
        'sent_at': nowIso,
        'metadata': _jsonEncodeMap(metadata),
        'version': 0,
      },
    );
  }

  @override
  Future<void> updateMessageMetadata(
    String messageId,
    Map<String, dynamic> metadata,
  ) async {
    await _databases.updateDocument(
      databaseId: appwriteDatabaseId,
      collectionId: _kMessagesCollectionId,
      documentId: messageId,
      data: {
        'metadata': _jsonEncodeMap(metadata),
      },
    );
  }

  @override
  Future<Map<String, dynamic>> fetchMessageRow(String messageId) async {
    final doc = await _databases.getDocument(
      databaseId: appwriteDatabaseId,
      collectionId: _kMessagesCollectionId,
      documentId: messageId,
    );
    return _documentToMessageRow(doc);
  }

  @override
  Future<void> deleteMessage(
    String messageId,
    String authorId,
    String currentUserId,
    String nowIso,
  ) async {
    final text = authorId == currentUserId
        ? 'this message was deleted'
        : 'this message was deleted by admin';
    await _databases.updateDocument(
      databaseId: appwriteDatabaseId,
      collectionId: _kMessagesCollectionId,
      documentId: messageId,
      data: {
        'text': text,
        'uri': null,
        'metadata': _jsonEncodeMap(const {'type': 'text'}),
        'deleted_at': nowIso,
      },
    );
  }

  @override
  Future<void> markMessageAsSeen(
    String messageId,
    String userId,
    String nowIso,
  ) async {
    final existing = await _databases.listDocuments(
      databaseId: appwriteDatabaseId,
      collectionId: _kMessageReceiptsCollectionId,
      queries: [
        Query.equal('message_id', messageId),
        Query.equal('user_id', userId),
        Query.limit(1),
      ],
    );
    if (existing.documents.isEmpty) {
      await _databases.createDocument(
        databaseId: appwriteDatabaseId,
        collectionId: _kMessageReceiptsCollectionId,
        documentId: ID.unique(),
        data: {
          'message_id': messageId,
          'user_id': userId,
          'seen_at': nowIso,
          'version': 0,
        },
      );
    } else {
      final row = existing.documents.first;
      await _databases.updateDocument(
        databaseId: appwriteDatabaseId,
        collectionId: _kMessageReceiptsCollectionId,
        documentId: row.$id,
        data: {
          'seen_at': nowIso,
        },
      );
    }
  }

  @override
  Future<Map<String, dynamic>> resolveUser(String id) async {
    final doc = await _databases.getDocument(
      databaseId: appwriteDatabaseId,
      collectionId: _kProfilesCollectionId,
      documentId: id,
    );
    return {
      'display_name': doc.data['display_name'],
      'avatar_url': doc.data['avatar_url'],
    };
  }

  @override
  ChatRealtimeHandle subscribeToChannel({
    required String channelId,
    required void Function(Map<String, dynamic> payload) onInsert,
    required void Function(Map<String, dynamic> payload) onUpdate,
    void Function(Map<String, dynamic> payload)? onDelete,
  }) {
    final channel = [
      'databases.$appwriteDatabaseId.collections.$_kMessagesCollectionId.documents',
    ];
    final sub = _realtime.subscribe(
      channel,
      queries: [Query.equal('channel_id', channelId)],
    );
    void handleMessage(RealtimeMessage message) {
      var action = _eventSuffix(message.events);
      if (action.isEmpty) {
        for (final e in message.events) {
          if (e.contains('documents') && e.contains('create')) {
            action = 'create';
            break;
          }
          if (e.contains('documents') && e.contains('update')) {
            action = 'update';
            break;
          }
          if (e.contains('documents') && e.contains('delete')) {
            action = 'delete';
            break;
          }
        }
      }
      final row = _mapPayloadToMessageRow(
        Map<String, dynamic>.from(message.payload),
      );
      if (action != 'delete') {
        final rch = row['channel_id']?.toString() ?? '';
        if (rch.isNotEmpty && rch != channelId) return;
      }
      switch (action) {
        case 'create':
          onInsert(row);
        case 'update':
          onUpdate(row);
        case 'delete':
          onDelete?.call(row);
        default:
          break;
      }
    }

    // ignore: cancel_subscriptions — lifetime tied to [ChatRealtimeHandle]
    sub.stream.listen(handleMessage);
    return ChatRealtimeHandle(close: sub.close);
  }
}