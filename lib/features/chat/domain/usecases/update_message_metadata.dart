import 'package:flutter_chat_core/flutter_chat_core.dart' as types;

import '../repositories/chat_repository.dart';

class UpdateMessageMetadata {
  final ChatRepository repository;

  UpdateMessageMetadata(this.repository);

  Future<void> call({
    required String channelId,
    required types.Message message,
  }) {
    return repository.updateMessageMetadata(
      channelId: channelId,
      message: message,
    );
  }
}
