import 'package:flutter/material.dart';

import 'package:WhatsUnity/core/config/Enums.dart';
import 'package:WhatsUnity/features/chat/data/models/chat_member_model.dart';

ChatMember fallbackSocialMember(String id) {
  return ChatMember(
    id: id,
    displayName: 'Unknown',
    building: 'null',
    apartment: 'null',
    userState: UserState.banned,
    phoneNumber: '',
    ownerType: null,
  );
}

ImageProvider<Object> socialAvatarProvider(String? avatarUrl) {
  if (avatarUrl != null && avatarUrl.isNotEmpty) {
    return NetworkImage(avatarUrl);
  }
  return const AssetImage('assets/defaultUser.webp');
}
