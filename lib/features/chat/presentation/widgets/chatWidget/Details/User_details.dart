
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:WhatsUnity/core/theme/lightTheme.dart';
import '../../../../../auth/presentation/bloc/auth_cubit.dart';
import '../../../../../auth/presentation/bloc/auth_state.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../../../core/config/Enums.dart';
import 'package:WhatsUnity/features/chat/data/models/chat_member_model.dart';
import 'package:WhatsUnity/features/chat/presentation/bloc/presence_cubit.dart';
import 'package:WhatsUnity/features/chat/presentation/bloc/presence_state.dart';


class UserDetails extends StatelessWidget {
  final String userID;
  const UserDetails({super.key, required this.userID});

  ({String status, DateTime? lastSeenAt}) _resolveLivePresence(
    List<SinglePresenceState> states,
  ) {
    String resolvedStatus = 'offline';
    DateTime? latestSeenAt;
    for (final singleState in states) {
      for (final presence in singleState.presences) {
        if (presence.payload['user_id']?.toString() != userID) continue;
        final candidateStatus =
            presence.payload['status']?.toString() ?? 'offline';
        final rawLastSeen = presence.payload['last_seen_at']?.toString();
        final parsedLastSeen =
            rawLastSeen == null ? null : DateTime.tryParse(rawLastSeen)?.toLocal();
        final shouldReplace = latestSeenAt == null ||
            (parsedLastSeen != null && parsedLastSeen.isAfter(latestSeenAt));
        if (shouldReplace) {
          latestSeenAt = parsedLastSeen ?? latestSeenAt;
          resolvedStatus = candidateStatus;
        }
      }
    }
    return (status: resolvedStatus, lastSeenAt: latestSeenAt);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, authState) {
        final chatMembers = (authState is Authenticated) ? authState.chatMembers : <ChatMember>[];
        final ChatMember member = chatMembers.firstWhere(
          (m) => m.id == userID,
          orElse: () => ChatMember(
            id: userID,
            displayName: 'Unknown',
            avatarUrl: null,
            building: '',
            apartment: '', userState: UserState.banned , phoneNumber: '', ownerType: null,
          ),
        );
        return BlocBuilder<PresenceCubit, PresenceState>(
          builder: (context, presenceState) {
            final states = presenceState is PresenceUpdated
                ? presenceState.currentPresence
                : context.read<PresenceCubit>().currentPresence;
            final presence = _resolveLivePresence(states);
            final liveStatus = presence.status;
            final lastSeenLabel = liveStatus == 'typing'
                ? 'Typing now'
                : (liveStatus == 'online'
                    ? 'Online now'
                    : context.loc.lastSeenTodayAt(
                        presence.lastSeenAt != null
                            ? TimeOfDay.fromDateTime(presence.lastSeenAt!)
                                .format(context)
                            : '--:--',
                      ));
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
            CircleAvatar(
              // Display user avatar or a default icon
              backgroundImage: member.avatarUrl != null
                  ? CachedNetworkImageProvider(member.avatarUrl!)
                  : null,
              radius: 40,
              child: member.avatarUrl == null ? Icon(Icons.person , size: 60,) : null,
            ),
            Text(member.displayName),
            Text(member.phoneNumber),
            Text(
              liveStatus == 'typing'
                  ? 'Typing now'
                  : (liveStatus == 'online' ? 'Online' : 'Offline'),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 10,
              children: [
              Container(
                alignment: Alignment.center,
                height: 55,
                width: MediaQuery.sizeOf(context).width*0.20,
                decoration: BoxDecoration(
                  color: Colors.blue.shade200,
                  borderRadius: BorderRadius.circular(10),

                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FaIcon(FontAwesomeIcons.whatsapp),
                    Text(context.loc.whatsapp)
                  ],
                ),
              ),

              Container(
                height: 55,
                width: MediaQuery.sizeOf(context).width*0.20,
                decoration: BoxDecoration(
                    color: Colors.blue.shade200,
                    borderRadius: BorderRadius.circular(10)
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(height: 7,),
                    FaIcon(FontAwesomeIcons.exclamation),
                    Text(context.loc.report)
                  ],
                ),
              ),
            ],),
            const SizedBox(height: 8),
            Text(lastSeenLabel)
          ],
        );
          },
        );
      },
    );
  }
}
