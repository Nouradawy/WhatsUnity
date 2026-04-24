import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/config/Enums.dart';
import '../../../../core/config/supabase.dart';
import '../../../../core/models/ReportAUser.dart';
import '../../../admin/presentation/bloc/admin_cubit.dart';
import '../widgets/chatWidget/Details/ChatMember.dart';
import 'chat_details_state.dart';

import '../../../../features/auth/presentation/bloc/auth_cubit.dart';
import '../../../../features/auth/presentation/bloc/auth_state.dart';

class ChatDetailsCubit extends Cubit<ChatDetailsStates> {
  final AuthCubit authCubit;
  ChatDetailsCubit({required this.authCubit}) : super(ChatInitialState());
  
  static ChatDetailsCubit get(context) => BlocProvider.of(context);

  int selectedIndex = 0;
  bool isExpanded = false;
  String? selectedMemberId;
  NavigationRailLabelType labelType = NavigationRailLabelType.all;

  void indexChange(int index){
    selectedIndex = index;
    selectedMemberId = null;
    emit(ChatDetailsIndexChange());
  }

  void selectMember(String id) {
    selectedMemberId = id;
    emit(ChatDetailsMemberSelected());
  }

  void clearSelectedMember() {
    selectedMemberId = null;
    emit(ChatDetailsMemberCleared());
  }

  void expandReport (int currentIndex){
    selectedIndex = currentIndex;
    isExpanded = !isExpanded;
    emit(ExpandReportState());
  }

  List<ReportAUsers> reportFilterUser(BuildContext context , String userId)  {
    final adminCubit = context.read<AdminCubit>();
    final reportList = adminCubit.userReports;
    return reportList
        .where((report) => report.reportedUserId == userId)
        .map((e) => ReportAUsers(
              id: e.id,
              authorId: e.authorId,
              createdAt: e.createdAt,
              reportedUserId: e.reportedUserId,
              state: e.state,
              description: e.description,
              messageId: e.messageId,
              reportedFor: e.reportedFor,
            ))
        .toList();
  }

  Future<void> banUser(String userid, UserState banType) async {
    await supabase.from('profiles').update({"userState": banType.name}).eq('id', userid);
    final currentState = authCubit.state;
    if (currentState is Authenticated) {
      final updatedMembers = currentState.chatMembers.map((m) {
        if (m.id == userid) {
          return ChatMember(
              id: m.id,
              displayName: m.displayName,
              building: m.building,
              apartment: m.apartment,
              userState: banType,
              phoneNumber: m.phoneNumber,
              ownerType: m.ownerType,
              avatarUrl: m.avatarUrl,
              fullName: m.fullName);
        }
        return m;
      }).toList();
      authCubit.updateChatMembers(updatedMembers);
    }
    emit(BanMemberState());
  }

  void onProfileUpdated(ChatMember member) {
    emit(ProfileUpdatedState(member: member));
  }
}
