import '../../data/models/chat_member_model.dart';

abstract class ChatDetailsStates {}

class ChatInitialState extends ChatDetailsStates {}

class ChatDetailsIndexChange extends ChatDetailsStates {}

class ChatDetailsMemberSelected extends ChatDetailsStates {}

class ChatDetailsMemberCleared extends ChatDetailsStates {}

class ExpandReportState extends ChatDetailsStates {}

class BanMemberState extends ChatDetailsStates {}

class ProfileUpdatedState extends ChatDetailsStates {
  final ChatMember member;
  ProfileUpdatedState({required this.member});
}
