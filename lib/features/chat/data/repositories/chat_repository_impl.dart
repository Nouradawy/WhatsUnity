import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' as types;
import 'package:WhatsUnity/core/utils/app_logger.dart';

import '../../../../core/sync/lww_merge.dart';
import '../../../../core/time/trusted_utc_now.dart';
import '../../domain/repositories/chat_repository.dart';
import '../datasources/chat_local_data_source.dart';
import '../datasources/chat_realtime_handle.dart';
import '../datasources/chat_remote_data_source.dart';
import '../models/message_model.dart';

class ChatRepositoryImpl implements ChatRepository {
  ChatRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  final ChatRemoteDataSource remoteDataSource;
  final ChatLocalDataSource localDataSource;

  @override
  /// UI provides [channelId] as Appwrite `channels` document `$id`.
  /// We read local first, then pull remote rows and re-emit.
  Future<List<types.Message>> fetchMessages({
    required String channelId,
    required String currentUserId,
    required int pageSize,
    required int pageNum,
    void Function(List<types.Message> messages, int pageNum)? onRemoteSynced,
  }) async {
    var cached = <types.Message>[];
    try {
      final rows = await localDataSource.local_getMessagesByChannelWithPagination(
        channelId: channelId,
        limit: pageSize,
        offset: pageNum * pageSize,
      );
      cached = rows.map(MessageModel.fromMap).toList();
    } catch (e, st) {
      AppLogger.e("fetchMessages local failed", tag: 'ChatRepository', error: e, stackTrace: st);
    }

    // For first-page sync, use local newest createdAt as a cursor so Appwrite
    // only returns rows newer than what we already have cached.
    final DateTime? sinceCreatedAt = pageNum == 0 && cached.isNotEmpty
        ? cached.last.createdAt?.toUtc()
        : null;

    unawaited(_syncRemoteThenNotify(
      channelId: channelId,
      currentUserId: currentUserId,
      pageSize: pageSize,
      pageNum: pageNum,
      sinceCreatedAt: sinceCreatedAt,
      onRemoteSynced: onRemoteSynced,
    ));

    return cached;
  }

  Future<void> _syncRemoteThenNotify({
    required String channelId,
    required String currentUserId,
    required int pageSize,
    required int pageNum,
    DateTime? sinceCreatedAt,
    void Function(List<types.Message> messages, int pageNum)? onRemoteSynced,
  }) async {
    try {
      final raw = await remoteDataSource.remote_fetchMessages(
        channelId: channelId,
        currentUserId: currentUserId,
        pageSize: pageSize,
        pageNum: pageNum,
        sinceCreatedAt: sinceCreatedAt,
      );
      List<types.Message> syncedMessages;
      try {
        await localDataSource.local_insertMessages(raw);
        final rows = await localDataSource.local_getMessagesByChannelWithPagination(
          channelId: channelId,
          limit: pageSize,
          offset: pageNum * pageSize,
        );
        syncedMessages = rows.map(MessageModel.fromMap).toList();
      } catch (e, st) {
        // Web/PWA fallback: if local DB initialization or writes fail, still
        // surface the remote payload so chat can render instead of staying empty.
        AppLogger.e("fetchMessages local persist fallback", tag: 'ChatRepository', error: e, stackTrace: st);
        syncedMessages = raw.map(MessageModel.fromMap).toList();
      }
      if (onRemoteSynced != null) {
        onRemoteSynced(syncedMessages, pageNum);
      }
    } catch (e, st) {
      AppLogger.e("fetchMessages remote sync failed", tag: 'ChatRepository', error: e, stackTrace: st);
    }
  }

  @override
  Future<void> sendTextMessage({
    required String text,
    required String channelId,
    required String userId,
    types.Message? repliedMessage,
  }) async {
    final now = await trustedUtcNow();
    await remoteDataSource.remote_sendTextMessage(
      text: text,
      channelId: channelId,
      userId: userId,
      nowIso: now.toIso8601String(),
      nowMs: now.millisecondsSinceEpoch,
      repliedMessageId: repliedMessage?.id,
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
    Map<String, dynamic>? additionalMetadata,
  }) async {
    final now = await trustedUtcNow();
    await remoteDataSource.remote_sendFileMessage(
      uri: uri,
      name: name,
      size: size,
      channelId: channelId,
      userId: userId,
      type: type,
      nowIso: now.toIso8601String(),
      nowMs: now.millisecondsSinceEpoch,
      additionalMetadata: additionalMetadata,
    );
  }

  @override
  Future<void> sendVoiceNote({
    required String uri,
    required Duration duration,
    required List<double> waveform,
    required String channelId,
    required String userId,
  }) async {
    final now = await trustedUtcNow();
    await remoteDataSource.remote_sendVoiceNote(
      uri: uri,
      duration: duration,
      waveform: waveform,
      channelId: channelId,
      userId: userId,
      nowIso: now.toIso8601String(),
      nowMs: now.millisecondsSinceEpoch,
    );
  }

  @override
  Future<bool> markMessageAsSeen(String messageId, String userId) async {
    try {
      final now = await trustedUtcNow();
      await remoteDataSource.remote_markMessageAsSeen(
        messageId,
        userId,
        now.toIso8601String(),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> deleteMessage(types.Message message, String currentUserId) async {
    final now = await trustedUtcNow();
    await remoteDataSource.remote_deleteMessage(
      message.id,
      message.authorId,
      currentUserId,
      now.toIso8601String(),
    );
  }

  @override
  /// Persists metadata changes (reactions/poll updates) remotely, then caches locally.
  Future<void> updateMessageMetadata({
    required String channelId,
    required types.Message message,
  }) async {
    final meta = message.metadata;
    if (meta == null) return;
    await remoteDataSource.remote_updateMessageMetadata(
      message.id,
      Map<String, dynamic>.from(meta),
    );
    try {
      await localDataSource.local_insertMessagesFromTypes(channelId, [message]);
    } catch (e, st) {
      AppLogger.e(
        "updateMessageMetadata: local SQLite persist failed",
        tag: 'ChatRepository',
        error: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<types.Message?> fetchMessageById(String messageId) async {
    if (messageId.isEmpty) return null;
    try {
      final row = await remoteDataSource.remote_fetchMessageRow(messageId);
      final msg = MessageModel.fromMap(row);
      try {
        final ch = MessageModel.channelIdFromRow(row);
        if (ch.isNotEmpty) {
          await localDataSource.local_insertMessagesFromTypes(ch, [msg]);
        }
      } catch (e, st) {
        AppLogger.e("fetchMessageById local persist failed", tag: 'ChatRepository', error: e, stackTrace: st);
      }
      return msg;
    } catch (e, st) {
      AppLogger.e("fetchMessageById failed", tag: 'ChatRepository', error: e, stackTrace: st);
      return null;
    }
  }

  @override
  Future<types.User> resolveUser(String id) async {
    if (id == 'deleted_user') {
      return const types.User(id: 'deleted_user', name: 'Deleted User');
    }
    try {
      final userData = await remoteDataSource.remote_resolveUser(id);
      final rawAvatar = userData['avatar_url']?.toString().trim();
      final avatarUrl = (rawAvatar == null ||
              rawAvatar.isEmpty ||
              rawAvatar.toLowerCase() == 'null')
          ? null
          : rawAvatar;
      return types.User(
        id: id,
        name: userData['display_name']?.toString() ?? 'Unknown',
        imageSource: avatarUrl,
      );
    } catch (error) {
      return types.User(id: id, name: 'Unknown');
    }
  }

  @override
  /// Subscribes to Appwrite realtime for one [channelId] document id.
  ChatRealtimeHandle subscribeToChannel({
    required String channelId,
    required void Function(types.Message message) onInsert,
    required void Function(types.Message message) onUpdate,
    void Function(types.Message message)? onDelete,
  }) {
    return remoteDataSource.remote_subscribeToChannel(
      channelId: channelId,
      onInsert: (payload) {
        final map = Map<String, dynamic>.from(payload);
        unawaited(_persistLocal(map, 'insert'));
        onInsert(MessageModel.fromMap(map));
      },
      onUpdate: (payload) {
        final map = Map<String, dynamic>.from(payload);
        unawaited(_persistLocal(map, 'update'));
        onUpdate(MessageModel.fromMap(map));
      },
      onDelete: onDelete != null
          ? (payload) {
              final map = Map<String, dynamic>.from(payload);
              final id = map['id']?.toString();
              if (id != null) {
                unawaited(localDataSource.local_deleteMessageById(id));
              }
              try {
                onDelete(MessageModel.fromMap(map));
              } catch (_) {
                if (id != null) {
                  onDelete(
                    types.TextMessage(
                      id: id,
                      authorId: map['author_id']?.toString() ?? '',
                      text: '',
                    ),
                  );
                }
              }
            }
          : null,
    );
  }

  @override
  Future<String?> resolveChannelDocumentId({
    required String compoundId,
    required String channelType,
    String? buildingNameForScopedChat,
  }) {
    return remoteDataSource.remote_resolveChannelDocumentId(
      compoundId: compoundId,
      channelType: channelType,
      buildingNameForScopedChat: buildingNameForScopedChat,
    );
  }

  Future<void> _persistLocal(Map<String, dynamic> map, String reason) async {
    try {
      final id = map['id']?.toString();
      if (id != null && id.isNotEmpty) {
        final local = await localDataSource.local_getRawMessageRow(id);
        if (!shouldApplyRemoteToLocal(localRow: local, remoteRow: map)) {
          return;
        }
      }
      await localDataSource.local_insertMessage(map);
    } catch (e, st) {
      AppLogger.e("local persist ($reason) failed", tag: 'ChatRepository', error: e, stackTrace: st);
    }
  }
}
