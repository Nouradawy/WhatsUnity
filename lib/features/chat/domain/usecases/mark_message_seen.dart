import '../repositories/chat_repository.dart';

class MarkMessageSeen {
  final ChatRepository repository;

  MarkMessageSeen(this.repository);

  Future<bool> call(String messageId, String userId) {
    return repository.markMessageAsSeen(messageId, userId);
  }
}
