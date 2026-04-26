import '../../features/chat/presentation/widgets/chatWidget/Details/ChatMember.dart';

/// Admin-only verification file metadata loaded with compound members.
class Users {
  final String authorId;
  final String phoneNumber;
  final DateTime updatedAt;
  final String ownerShipType;
  final String userState;
  final String actionTakenBy;
  final List<Map<String, dynamic>> verFile;

  Users({
    required this.authorId,
    required this.phoneNumber,
    required this.updatedAt,
    required this.ownerShipType,
    required this.userState,
    required this.actionTakenBy,
    required this.verFile,
  });
}

/// Result of loading all members for one compound (UI + admin payloads).
class CompoundMembersResult {
  final List<ChatMember> members;
  final List<Users> membersData;

  CompoundMembersResult({
    required this.members,
    required this.membersData,
  });
}
