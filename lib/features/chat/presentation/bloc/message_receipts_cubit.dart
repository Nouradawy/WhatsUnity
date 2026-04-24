import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/config/Enums.dart';

import '../widgets/chatWidget/Details/ChatMember.dart';
import 'message_receipts_state.dart';

class SeenUser {
  final ChatMember member;
  final DateTime seenAt;
  SeenUser({required this.member, required this.seenAt});
}

class MessageReceiptsCubit extends Cubit<MessageReceiptsState> {
  final SupabaseClient client;
  final List<ChatMember> chatMembers;
  MessageReceiptsCubit(this.client, {required this.chatMembers}) : super(const MessageReceiptsInitial());

  Future<void> fetchSeenUsers(String messageId) async {
    emit(const MessageReceiptsLoading());
    try {
      final rows = await client
          .from('message_receipts')
          .select('user_id, seen_at')
          .eq('message_id', messageId)
          .not('seen_at', 'is', null);

      final List<dynamic> list = rows as List<dynamic>;
      final List<SeenUser> mapped = [];
      for (final r in list) {
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
      // Sort newest first
      mapped.sort((a, b) => b.seenAt.compareTo(a.seenAt));
      emit(MessageReceiptsLoaded(mapped));
    } catch (e) {
      emit(MessageReceiptsError(e.toString()));
    }
  }
}
