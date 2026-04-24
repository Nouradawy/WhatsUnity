
import 'package:flutter_chat_core/flutter_chat_core.dart' as types;

import '../repositories/chat_repository.dart';

class FetchMessages {
  final ChatRepository repository;

  FetchMessages(this.repository);

  Future<List<types.Message>> call({
    required String channelId,
    required String currentUserId,
    required int pageSize,
    required int pageNum,
    void Function(List<types.Message> messages, int pageNum)? onRemoteSynced,
  }) {
    return repository.fetchMessages(
      channelId: channelId,
      currentUserId: currentUserId,
      pageSize: pageSize,
      pageNum: pageNum,
      onRemoteSynced: onRemoteSynced,
    );
  }
}
