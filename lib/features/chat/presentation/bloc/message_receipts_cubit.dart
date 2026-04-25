import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/config/Enums.dart';
import '../../data/datasources/chat_remote_data_source.dart';
import '../widgets/chatWidget/Details/ChatMember.dart';
import 'message_receipts_state.dart';

class SeenUser {
  final ChatMember member;
  final DateTime seenAt;
  SeenUser({required this.member, required this.seenAt});
}

class MessageReceiptsCubit extends Cubit<MessageReceiptsState> {
  MessageReceiptsCubit(
    this._remote, {
    required this.chatMembers,
  }) : super(const MessageReceiptsInitial());

  final ChatRemoteDataSource _remote;
  final List<ChatMember> chatMembers;

  Future<void> fetchSeenUsers(String messageId) async {
    emit(const MessageReceiptsLoading());
    try {
      final rows = await _remote.remote_listSeenReceiptsForMessage(messageId);
      final mapped = <SeenUser>[];
      for (final r in rows) {
        final uid = (r['user_id'] as String?)?.trim();
        if (uid == null) continue;
        final cm = chatMembers.firstWhere(
          (m) => m.id.trim() == uid,
          orElse: () => ChatMember(
            id: uid,
            displayName: 'Unknown',
            building: '',
            apartment: '',
            userState: UserState.banned,
            phoneNumber: '',
            ownerType: null,
            fullName: 'Unknown',
            avatarUrl: null,
          ),
        );
        final rawSeen = r['seen_at'];
        DateTime? seenAt;
        if (rawSeen is String) {
          seenAt = DateTime.tryParse(rawSeen)?.toLocal();
        } else if (rawSeen is DateTime) {
          seenAt = rawSeen.toLocal();
        }
        if (seenAt != null) {
          mapped.add(SeenUser(member: cm, seenAt: seenAt));
        }
      }
      mapped.sort((a, b) => b.seenAt.compareTo(a.seenAt));
      emit(MessageReceiptsLoaded(mapped));
    } catch (e) {
      emit(MessageReceiptsError(e.toString()));
    }
  }
}
