
import 'package:flutter_chat_core/flutter_chat_core.dart' as types;

import '../repositories/chat_repository.dart';

class DeleteMessage {
  final ChatRepository repository;

  DeleteMessage(this.repository);

  Future<void> call(types.Message message) {
    return repository.deleteMessage(message);
  }
}
