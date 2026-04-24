import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

import '../../domain/repositories/chat_repository.dart';
import '../../domain/usecases/delete_message.dart';
import '../../domain/usecases/fetch_messages.dart';
import '../../domain/usecases/mark_message_seen.dart';
import '../../domain/usecases/resolve_user.dart';
import '../../domain/usecases/send_file_message.dart';
import '../../domain/usecases/send_text_message.dart';
import '../../domain/usecases/send_voice_note.dart';
import '../../domain/usecases/subscribe_to_channel.dart';
import '../../domain/usecases/update_message_metadata.dart';
import '../bloc/chat_cubit.dart';

/// Provides an isolated [ChatCubit] (in-memory messages + realtime) per
/// **compound** and **channel kind**.
///
/// SQLite uses a single `messages` table; rows are already scoped by Supabase
/// `channel_id`. The bug this fixes is **sharing one [ChatCubit]** between
/// compound general chat and building chat, which reused the same list and hid
/// per-channel data even though the DB was correct.
class ChatScope extends StatelessWidget {
  const ChatScope({
    super.key,
    required this.compoundId,
    required this.channelScopeId,
    required this.userId,
    required this.child,
  });

  final String compoundId;
  /// e.g. `COMPOUND_GENERAL` or `BUILDING_CHAT` (must match [GeneralChat] query).
  final String channelScopeId;
  /// Signed-in user id — included in the provider key so each session gets a clean cubit.
  final String userId;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final repo = context.read<ChatRepository>();
    return BlocProvider<ChatCubit>(
      key: ValueKey('chat_${userId}_${compoundId}_$channelScopeId'),
      create: (_) => ChatCubit(
        fetchMessagesUsecase: FetchMessages(repo),
        sendTextMessageUsecase: SendTextMessage(repo),
        sendFileMessageUsecase: SendFileMessage(repo),
        sendVoiceNoteUsecase: SendVoiceNote(repo),
        markMessageSeenUsecase: MarkMessageSeen(repo),
        deleteMessageUsecase: DeleteMessage(repo),
        resolveUserUsecase: ResolveUser(repo),
        subscribeToChannelUsecase: SubscribeToChannel(repo),
        updateMessageMetadataUsecase: UpdateMessageMetadata(repo),
      ),
      child: child,
    );
  }
}
