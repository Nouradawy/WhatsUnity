import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' as types;

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
      debugPrint('fetchMessages local: $e\n$st');
    }

    unawaited(_syncRemoteThenNotify(
      channelId: channelId,
      currentUserId: currentUserId,
      pageSize: pageSize,
      pageNum: pageNum,
      onRemoteSynced: onRemoteSynced,
    ));

    return cached;
  }

  Future<void> _syncRemoteThenNotify({
    required String channelId,
    required String currentUserId,
    required int pageSize,
    required int pageNum,
    void Function(List<types.Message> messages, int pageNum)? onRemoteSynced,
  }) async {
    try {
      final raw = await remoteDataSource.fetchMessages(
        channelId: channelId,
        currentUserId: currentUserId,
        pageSize: pageSize,
        pageNum: pageNum,
      );
      await localDataSource.local_insertMessages(raw);
      if (onRemoteSynced != null) {
        final rows = await localDataSource.local_getMessagesByChannelWithPagination(
          channelId: channelId,
          limit: pageSize,
          offset: pageNum * pageSize,
        );
        onRemoteSynced(
          rows.map(MessageModel.fromMap).toList(),
          pageNum,
        );
      }
    } catch (e, st) {
      debugPrint('fetchMessages remote sync: $e\n$st');
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
    await remoteDataSource.sendTextMessage(
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
    await remoteDataSource.sendFileMessage(
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
    await remoteDataSource.sendVoiceNote(
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
      await remoteDataSource.markMessageAsSeen(messageId, userId, now.toIso8601String());
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> deleteMessage(types.Message message, String currentUserId) async {
    final now = await trustedUtcNow();
    await remoteDataSource.deleteMessage(message.id, message.authorId, currentUserId, now.toIso8601String());
  }

  @override
  Future<void> updateMessageMetadata({
    required String channelId,
    required types.Message message,
  }) async {
    final meta = message.metadata;
    if (meta == null) return;
    await remoteDataSource.updateMessageMetadata(message.id, Map<String, dynamic>.from(meta));
    try {
      await localDataSource.local_insertMessagesFromTypes(channelId, [message]);
    } catch (e, st) {
      debugPrint(
        'updateMessageMetadata: local SQLite persist failed after remote save '
        '(UI should still refresh from cubit): $e\n$st',
      );
    }
  }

  @override
  Future<types.Message?> fetchMessageById(String messageId) async {
    if (messageId.isEmpty) return null;
    try {
      final row = await remoteDataSource.fetchMessageRow(messageId);
      final msg = MessageModel.fromMap(row);
      try {
        final ch = MessageModel.channelIdFromRow(row);
        if (ch.isNotEmpty) {
          await localDataSource.local_insertMessagesFromTypes(ch, [msg]);
        }
      } catch (e, st) {
        debugPrint('fetchMessageById local persist: $e\n$st');
      }
      return msg;
    } catch (e, st) {
      debugPrint('fetchMessageById: $e\n$st');
      return null;
    }
  }

  @override
  Future<types.User> resolveUser(String id) async {
    if (id == 'deleted_user') {
      return const types.User(id: 'deleted_user', name: 'Deleted User');
    }
    try {
      final userData = await remoteDataSource.resolveUser(id);
      return types.User(
        id: id,
        name: userData['display_name'] ?? 'Unknown',
        imageSource: userData['avatar_url'],
      );
    } catch (error) {
      return types.User(id: id, name: 'Unknown');
    }
  }

  @override
  ChatRealtimeHandle subscribeToChannel({
    required String channelId,
    required void Function(types.Message message) onInsert,
    required void Function(types.Message message) onUpdate,
    void Function(types.Message message)? onDelete,
  }) {
    return remoteDataSource.subscribeToChannel(
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
    return remoteDataSource.resolveChannelDocumentId(
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
      debugPrint('local persist ($reason): $e\n$st');
    }
  }
}
