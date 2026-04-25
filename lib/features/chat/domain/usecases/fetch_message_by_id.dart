import 'package:flutter_chat_core/flutter_chat_core.dart' as types;

import '../repositories/chat_repository.dart';

class FetchMessageById {
  FetchMessageById(this.repository);

  final ChatRepository repository;

  Future<types.Message?> call(String messageId) {
    return repository.fetchMessageById(messageId);
  }
}
