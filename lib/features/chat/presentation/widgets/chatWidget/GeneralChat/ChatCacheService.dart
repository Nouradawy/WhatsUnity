import 'package:flutter_chat_core/flutter_chat_core.dart' as types;
import 'package:flutter_chat_reactions/flutter_chat_reactions.dart';

import '../../../../data/datasources/chat_local_data_source.dart';
import '../../../../data/models/message_model.dart';

/// Persists chat messages per channel using SQLite (replaces SharedPreferences).
class ChatCacheService {
  ChatCacheService(this._local);

  final ChatLocalDataSource _local;

  Future<void> saveMessages(String channelId, List<types.Message> messages) async {
    await _local.local_insertMessagesFromTypes(channelId, messages);
  }

  Future<List<types.Message>> loadMessages(String channelId) async {
    final maps = await _local.local_getAllMessagesForChannelAscending(channelId);
    final unique = <String, types.Message>{};
    for (final map in maps) {
      final msg = MessageModel.fromMap(map);
      unique[msg.id] = msg;
    }
    return unique.values.toList();
  }

  void hydrateReactionsFromMessages(
    types.InMemoryChatController chatController,
    ReactionsController reactionsController,
  ) {
    for (final msg in chatController.messages) {
      final meta = msg.metadata;
      if (meta == null) continue;

      final raw = meta['reactions'];
      if (raw is! Map) continue;

      raw.forEach((emoji, usersRaw) {
        if (emoji == null || usersRaw is! Map) return;
        final e = emoji.toString();

        usersRaw.forEach((uid, val) {
          final isTrue = val == true || val == 1 || val == 'true';
          if (!isTrue) return;
          reactionsController.addReaction(msg.id, e);
        });
      });
    }
  }
}
