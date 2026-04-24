import 'package:flutter_chat_core/flutter_chat_core.dart' as types;
import '../repositories/chat_repository.dart';

class SendTextMessage {
  final ChatRepository repository;

  SendTextMessage(this.repository);

  Future<void> call({
    required String text,
    required String channelId,
    required String userId,
    types.Message? repliedMessage,
  }) {
    return repository.sendTextMessage(
      text: text,
      channelId: channelId,
      userId: userId,
      repliedMessage: repliedMessage,
    );
  }
}
