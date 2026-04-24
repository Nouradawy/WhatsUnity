
import 'package:flutter_chat_core/flutter_chat_core.dart' as types;
import 'package:WhatsUnity/features/chat/data/datasources/chat_realtime_handle.dart';
import '../repositories/chat_repository.dart';

class SubscribeToChannel {
  final ChatRepository repository;

  SubscribeToChannel(this.repository);

  ChatRealtimeHandle call({
    required String channelId,
    required void Function(types.Message message) onInsert,
    required void Function(types.Message message) onUpdate,
    void Function(types.Message message)? onDelete,
  }) {
    return repository.subscribeToChannel(
      channelId: channelId,
      onInsert: onInsert,
      onUpdate: onUpdate,
      onDelete: onDelete,
    );
  }
}
