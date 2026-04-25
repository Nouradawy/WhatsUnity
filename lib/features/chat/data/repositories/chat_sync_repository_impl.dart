import 'package:flutter_chat_core/flutter_chat_core.dart' as types;
import 'package:uuid/uuid.dart';

import '../../../../core/sync/sync_engine.dart';
import '../../../../core/time/trusted_utc_now.dart';
import '../../../../core/sync/sync_entity_types.dart';
import '../../../../core/sync/sync_job_local_data_source.dart';
import '../../../../core/sync/sync_op_type.dart';
import '../../domain/repositories/chat_sync_repository.dart';
import '../datasources/chat_local_data_source.dart';
import '../models/message_model.dart';

class ChatSyncRepositoryImpl implements ChatSyncRepository {
  ChatSyncRepositoryImpl({
    required ChatLocalDataSource local,
    required SyncJobLocalDataSource jobStore,
    required SyncEngine engine,
  }) : _local = local,
       _jobs = jobStore,
       _engine = engine;

  final ChatLocalDataSource _local;
  final SyncJobLocalDataSource _jobs;
  final SyncEngine _engine;

  @override
  Future<types.Message> sendTextMessageOfflineFirst({
    required String text,
    required String channelId,
    required String userId,
    String? repliedMessageId,
  }) async {
    final now = await trustedUtcNow();
    final docId = const Uuid().v4();
    final ms = now.millisecondsSinceEpoch;
    final map = <String, dynamic>{
      'id': docId,
      'author_id': userId,
      'channel_id': channelId,
      'text': text,
      'created_at': now.toIso8601String(),
      'created_at_ms': ms,
      'metadata': <String, dynamic>{
        'type': 'text',
        'createdAtMs': ms,
        if (repliedMessageId != null) 'reply_to': repliedMessageId,
      },
      'sent_at': now.toIso8601String(),
      'reply_to': repliedMessageId,
      'entity_version': 0,
      'sync_state': 'dirty',
      'local_updated_at': now.toIso8601String(),
      'version': 0,
      'is_synced': 0,
    };
    await _local.insertMessage(map);
    await _jobs.enqueue(
      entityType: SyncEntityTypes.messages,
      entityId: docId,
      opType: SyncOpType.create,
      payload: {
        'kind': 'text',
        'document_id': docId,
        'text': text,
        'channel_id': channelId,
        'user_id': userId,
        'now_iso': now.toIso8601String(),
        'now_ms': ms,
        'replied_message_id': repliedMessageId,
        'version': 0,
      },
    );
    _engine.kick();
    return MessageModel.fromMap(map);
  }

  @override
  Future<void> enqueueUploadMediaJob({
    required String messageId,
    required String localPath,
    String? filenameOverride,
    String? mimeType,
  }) async {
    await _jobs.enqueue(
      entityType: SyncEntityTypes.messages,
      entityId: messageId,
      opType: SyncOpType.uploadMedia,
      payload: {
        'message_id': messageId,
        'path': localPath,
        if (filenameOverride != null) 'filename_override': filenameOverride,
        if (mimeType != null) 'mime_type': mimeType,
      },
    );
    _engine.kick();
  }

  @override
  void kickSync() => _engine.kick();
}
