import '../repositories/chat_repository.dart';

class SendFileMessage {
  final ChatRepository repository;

  SendFileMessage(this.repository);

  Future<void> call({
    required String uri,
    required String name,
    required int size,
    required String channelId,
    required String userId,
    required String type,
    Map<String, dynamic>? additionalMetadata,
  }) {
    return repository.sendFileMessage(
      uri: uri,
      name: name,
      size: size,
      channelId: channelId,
      userId: userId,
      type: type,
      additionalMetadata: additionalMetadata,
    );
  }
}
