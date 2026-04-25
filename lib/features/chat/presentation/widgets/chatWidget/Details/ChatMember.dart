import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:url_launcher/url_launcher.dart';


import 'package:WhatsUnity/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:WhatsUnity/features/auth/presentation/bloc/auth_state.dart';
import 'package:WhatsUnity/features/chat/presentation/bloc/chat_details_cubit.dart';

import 'package:WhatsUnity/features/chat/presentation/bloc/presence_cubit.dart';
import 'package:WhatsUnity/features/chat/presentation/bloc/presence_state.dart';

import 'package:WhatsUnity/core/config/Enums.dart';
import 'package:WhatsUnity/core/utils/url_launcher_helper.dart';


// A simple data class to hold user information
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
        (e) => e.name == userStateStr,
      );
    }

    OwnerTypes? parsedOwnerType;
    if (ownerTypeStr != null) {
      parsedOwnerType = OwnerTypes.values.firstWhere(
        (e) => e.name == ownerTypeStr,
        orElse: () => OwnerTypes.owner,
      );
    }

    return ChatMember(
      id: json['id']?.toString() ?? '',
      displayName: json['display_name'] as String? ?? '',
      fullName: json['full_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
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
        (e) => e.name == userStateStr,
      );
    }

    OwnerTypes? parsedOwnerType = ownerType;
    if (ownerTypeStr != null) {
      parsedOwnerType = OwnerTypes.values.firstWhere(
        (e) => e.name == ownerTypeStr,
        orElse: () => ownerType ?? OwnerTypes.owner,
      );
    }

    return ChatMember(
      id: id,
      building: building,
      apartment: apartment,
      displayName: (json['display_name'] as String?) ?? displayName,
      fullName: (json['full_name'] as String?) ?? fullName,
      avatarUrl: (json['avatar_url'] as String?) ?? avatarUrl,
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

class ChatMembersScreen extends StatefulWidget {
  final String compoundId;
  final bool? isAdmin;
  const ChatMembersScreen({super.key, required this.compoundId , this.isAdmin});

  @override
  State<ChatMembersScreen> createState() => _ChatMembersScreenState();
}

class _ChatMembersScreenState extends State<ChatMembersScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _initializeScreen() async {
    setState(() {
      _isLoading = false;
    });
  }

  // Fetches the static list of all users in the compound

  // String _getUserStatus(Map<String, dynamic> presence, String userId) {
  //   for (final entry in presence.entries) {
  //     final presences = entry.value as List;
  //     for (final p in presences) {
  //       if (p['user_id'] == userId) {
  //         return p['status'] ?? 'offline';
  //       }
  //     }
  //   }
  //   return 'offline';
  // }

  Map<String, String> _getStatusesFromPresence(List<SinglePresenceState> stateList) {
    final statuses = <String, String>{};

    // 1. Loop through each connected client
    for (final singleState in stateList) {

      // 2. Loop through their active presences to get the payload
      for (final presence in singleState.presences) {

        final payload = presence.payload;
        final userId = payload['user_id'];
        final status = payload['status'] ?? 'offline';

        if (userId != null) {
          statuses[userId.toString()] = status.toString();
        }
      }
    }
    return statuses;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, authState) {
        final chatMembers = (authState is Authenticated) ? authState.chatMembers : <ChatMember>[];

        return BlocBuilder<PresenceCubit, PresenceState>(
          buildWhen: (previous, current) => current is PresenceUpdated,
          builder: (context, state) {
            final presenceList = (state is PresenceUpdated) ? state.currentPresence : context.read<PresenceCubit>().currentPresence;
            final statusMap = _getStatusesFromPresence(presenceList);

            return Scaffold(
              appBar: AppBar(),
              body: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                itemCount: chatMembers.length,
                itemBuilder: (context, index) {
                  final member = chatMembers[index];
                  final status = statusMap[member.id] ?? 'offline';
                  final cubit = ChatDetailsCubit.get(context);
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: member.avatarUrl != null
                          ? NetworkImage(member.avatarUrl!)
                          : null,
                      child: member.avatarUrl == null ? const Icon(Icons.person) : null,
                    ),
                    onTap: () {
                      if (widget.isAdmin == true) {
                        context.read<ChatDetailsCubit>().expandReport(index);
                      }
                    },
                    title: Text(member.displayName),
                    trailing: StatusIndicator(status: status),
                    subtitle: widget.isAdmin == true
                        ? AnimatedCrossFade(
                        firstChild: Text(
                            "Reported : ${cubit.reportFilterUser(context, member.id).length}"),
                        secondChild: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                "Reported : ${cubit.reportFilterUser(context, member.id).length}"),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  spacing: 7,
                                  children: [
                                    SizedBox(
                                      width: 60,
                                      child: MaterialButton(
                                        onPressed: () => launchUrl(Uri.parse(
                                            "tel:<${member.phoneNumber.toString()}>")),
                                        elevation: 0,
                                        color: Colors.greenAccent,
                                        padding: EdgeInsets.zero,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.phone,
                                                size: 17, color: Colors.white),
                                            Text(
                                              "CALL",
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                letterSpacing: 0.2,
                                                color: Colors.black87,
                                              ),
                                            )
                                          ],
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 60,
                                      child: MaterialButton(
                                        onPressed: () => openWhatsApp(
                                            member.phoneNumber.toString(), "Hello",
                                            defaultCountryCode: "20"),
                                        elevation: 0,
                                        color: Colors.greenAccent,
                                        padding: EdgeInsets.zero,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const FaIcon(FontAwesomeIcons.whatsapp,
                                                size: 17, color: Colors.white),
                                            Text(
                                              "WhatsApp",
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                letterSpacing: 0.2,
                                                color: Colors.black87,
                                              ),
                                            )
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  spacing: 7,
                                  children: [
                                    SizedBox(
                                      width: 60,
                                      child: MaterialButton(
                                        onPressed: () {
                                          cubit.banUser(
                                              member.id,
                                              member.userState == UserState.chatBanned
                                                  ? UserState.approved
                                                  : UserState.chatBanned);
                                          setState(() {});
                                        },
                                        elevation: 0,
                                        color: Colors.pinkAccent,
                                        padding: EdgeInsets.zero,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                                member.userState == UserState.chatBanned
                                                    ? Icons.chat_bubble
                                                    : Symbols.chat_error,
                                                size: 17,
                                                color: Colors.white),
                                            Text(
                                              member.userState == UserState.chatBanned
                                                  ? "Enable"
                                                  : "Chat Ban",
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                letterSpacing: 0.2,
                                                color: Colors.black87,
                                              ),
                                            )
                                          ],
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 60,
                                      child: MaterialButton(
                                        onPressed: () {
                                          cubit.banUser(
                                              member.id,
                                              member.userState == UserState.banned
                                                  ? UserState.approved
                                                  : UserState.banned);
                                          setState(() {});
                                        },
                                        elevation: 0,
                                        color: Colors.pink,
                                        padding: EdgeInsets.zero,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                                member.userState == UserState.banned
                                                    ? Icons.person
                                                    : Icons.no_accounts,
                                                size: 20,
                                                color: Colors.white),
                                            Text(
                                              member.userState == UserState.banned
                                                  ? "Unban"
                                                  : "Ban",
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                letterSpacing: 0.2,
                                                color: Colors.black87,
                                              ),
                                            )
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                        crossFadeState: (context.watch<ChatDetailsCubit>().isExpanded &&
                            context.watch<ChatDetailsCubit>().selectedIndex == index)
                            ? CrossFadeState.showSecond
                            : CrossFadeState.showFirst,
                        duration: const Duration(milliseconds: 500))
                        : null,
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

// A helper widget to display the status visually
class StatusIndicator extends StatelessWidget {
  final String status;
  const StatusIndicator({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    String statusText;

    switch (status) {
      case 'available':
        statusColor = Colors.green;
        statusText = 'Available';
        break;
      case 'online':
        statusColor = Colors.blue;
        statusText = 'Online';
        break;
      default: // 'offline'
        statusColor = Colors.grey;
        statusText = 'Offline';
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
        ),
        SizedBox(width: 8),
        Text(statusText),
      ],
    );
  }
}
