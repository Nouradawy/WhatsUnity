import '../../../../core/config/Enums.dart';
import '../../../../core/config/app_directory_types.dart';
import '../../../../core/models/CompoundsList.dart';
import '../../../chat/data/models/chat_member_model.dart';
import 'app_user.dart';

/// Encapsulates the result of [AuthRepository.prepareAuthSession].
class AuthSessionPreparationResult {
  final AppUser? user;
  final Roles? role;
  final String? selectedCompoundId;
  final Map<String, dynamic> myCompounds;
  final List<ChatMember> chatMembers;
  final List<Users> membersData;
  final ChatMember? currentUserMember;
  final List<Category> categories;
  final List<String> compoundsLogos;
  final bool isProfileIncomplete;

  AuthSessionPreparationResult({
    this.user,
    this.role,
    this.selectedCompoundId,
    required this.myCompounds,
    required this.chatMembers,
    required this.membersData,
    this.currentUserMember,
    required this.categories,
    required this.compoundsLogos,
    this.isProfileIncomplete = false,
  });
}
