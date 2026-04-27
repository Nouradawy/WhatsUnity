import 'package:WhatsUnity/core/config/Enums.dart';

/// App-level chat member model built from `profiles` + `user_apartments`.
class ChatMember {
  final String id;
  final String displayName;
  final String? fullName;
  final String? avatarUrl;
  final String building;
  final String apartment;
  final UserState? userState;
  final String phoneNumber;
  final OwnerTypes? ownerType;

  ChatMember({
    required this.id,
    required this.displayName,
    this.fullName,
    this.avatarUrl,
    required this.building,
    required this.apartment,
    required this.userState,
    required this.phoneNumber,
    required this.ownerType,
  });

  factory ChatMember.fromJson(Map<String, dynamic> json) {
    final String? userStateStr = json['userState'] as String?;
    final String? ownerTypeStr = json['owner_type'] as String?;

    UserState? parsedUserState;
    if (userStateStr != null) {
      parsedUserState = UserState.values.firstWhere(
        (state) => state.name == userStateStr,
        orElse: () => UserState.New,
      );
    }

    OwnerTypes? parsedOwnerType;
    if (ownerTypeStr != null) {
      parsedOwnerType = OwnerTypes.values.firstWhere(
        (ownerType) => ownerType.name == ownerTypeStr,
        orElse: () => OwnerTypes.owner,
      );
    }

    String? normalizedAvatar(dynamic rawAvatar) {
      final rawText = rawAvatar?.toString().trim();
      if (rawText == null ||
          rawText.isEmpty ||
          rawText.toLowerCase() == 'null') {
        return null;
      }
      return rawText;
    }

    return ChatMember(
      id: json['id']?.toString() ?? '',
      displayName: json['display_name'] as String? ?? '',
      fullName: json['full_name'] as String?,
      avatarUrl: normalizedAvatar(
        json['avatar_url'] ?? json['avatarUrl'] ?? json['avatar'],
      ),
      building: json['building_num']?.toString() ?? '',
      apartment: json['apartment_num']?.toString() ?? '',
      userState: parsedUserState,
      phoneNumber: json['phone_number']?.toString() ?? '',
      ownerType: parsedOwnerType,
    );
  }

  ChatMember copyWithProfileUpdate(Map<String, dynamic> json) {
    final String? userStateStr = json['userState'] as String?;
    final String? ownerTypeStr = json['owner_type'] as String?;

    UserState? parsedUserState = userState;
    if (userStateStr != null) {
      parsedUserState = UserState.values.firstWhere(
        (state) => state.name == userStateStr,
        orElse: () => userState ?? UserState.New,
      );
    }

    OwnerTypes? parsedOwnerType = ownerType;
    if (ownerTypeStr != null) {
      parsedOwnerType = OwnerTypes.values.firstWhere(
        (ownerType) => ownerType.name == ownerTypeStr,
        orElse: () => ownerType ?? OwnerTypes.owner,
      );
    }

    String? normalizedAvatar(dynamic rawAvatar) {
      final rawText = rawAvatar?.toString().trim();
      if (rawText == null ||
          rawText.isEmpty ||
          rawText.toLowerCase() == 'null') {
        return null;
      }
      return rawText;
    }

    return ChatMember(
      id: id,
      building: building,
      apartment: apartment,
      displayName: (json['display_name'] as String?) ?? displayName,
      fullName: (json['full_name'] as String?) ?? fullName,
      avatarUrl:
          normalizedAvatar(
            json['avatar_url'] ?? json['avatarUrl'] ?? json['avatar'],
          ) ??
          avatarUrl,
      phoneNumber: (json['phone_number'] as String?) ?? phoneNumber,
      userState: parsedUserState,
      ownerType: parsedOwnerType,
    );
  }

  @override
  String toString() {
    return 'ChatMember(id: $id, name: $displayName, building: $building, apartment: $apartment)';
  }
}
