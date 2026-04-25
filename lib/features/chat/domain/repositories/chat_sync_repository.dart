import 'package:flutter_chat_core/flutter_chat_core.dart' as types;

/// Offline-first chat writes: local `sqflite` + [sync_jobs] + [SyncEngine].
abstract class ChatSyncRepository {
  /// Persists a text message locally as `dirty`, enqueues CREATE, kicks sync.
  Future<types.Message> sendTextMessageOfflineFirst({
    required String text,
    required String channelId,
    required String userId,
    String? repliedMessageId,
  });

  /// Queue an offline media upload after the message document exists remotely.
  Future<void> enqueueUploadMediaJob({
    required String messageId,
    required String localPath,
    String? filenameOverride,
    String? mimeType,
  });

  void kickSync();
}
