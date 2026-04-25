
import 'package:flutter_chat_core/flutter_chat_core.dart' as types;
import 'package:WhatsUnity/features/chat/data/datasources/chat_realtime_handle.dart';

abstract class ChatRepository {
  /// Offline-first: completes quickly with SQLite page; [onRemoteSynced] merges Appwrite rows.
  Future<List<types.Message>> fetchMessages({
    required String channelId,
    required String currentUserId,
    required int pageSize,
    required int pageNum,
    void Function(List<types.Message> messages, int pageNum)? onRemoteSynced,
  });

  Future<void> sendTextMessage({
    required String text,
    required String channelId,
    required String userId,
    types.Message? repliedMessage,
  });

  Future<void> sendFileMessage({
    required String uri,
    required String name,
    required int size,
    required String channelId,
    required String userId,
    required String type, // 'image', 'file', 'audio'
    Map<String, dynamic>? additionalMetadata,
  });

  Future<void> sendVoiceNote({
    required String uri,
    required Duration duration,
    required List<double> waveform,
    required String channelId,
    required String userId,
  });

  Future<bool> markMessageAsSeen(String messageId, String userId);

  Future<void> deleteMessage(types.Message message, String currentUserId);

  /// Writes [message.metadata] to Appwrite and replaces the local SQLite row.
  Future<void> updateMessageMetadata({
    required String channelId,
    required types.Message message,
  });

  /// Loads one message from Appwrite (e.g. refresh [metadata] when realtime lags).
  Future<types.Message?> fetchMessageById(String messageId);

  Future<types.User> resolveUser(String id);

  ChatRealtimeHandle subscribeToChannel({
    required String channelId,
    required void Function(types.Message message) onInsert,
    required void Function(types.Message message) onUpdate,
    void Function(types.Message message)? onDelete,
  });

  /// Maps compound + channel type (+ optional building name) to Appwrite `channels.$id`.
  Future<String?> resolveChannelDocumentId({
    required String compoundId,
    required String channelType,
    String? buildingNameForScopedChat,
  });
}
