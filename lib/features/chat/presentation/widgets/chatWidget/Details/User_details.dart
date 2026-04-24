
import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../auth/presentation/bloc/auth_cubit.dart';
import '../../../../../auth/presentation/bloc/auth_state.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../../../core/config/Enums.dart';
import '../../../../../../core/config/supabase.dart';
import 'ChatMember.dart';


class UserDetails extends StatelessWidget {
  final String userID;
  const UserDetails({super.key, required this.userID});

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
        return Column(
          children: [
            CircleAvatar(
              // Display user avatar or a default icon
              backgroundImage: member.avatarUrl != null ? NetworkImage(member.avatarUrl!) : null,
              radius: 40,
              child: member.avatarUrl == null ? Icon(Icons.person , size: 60,) : null,
            ),
            Text(member.displayName),
            Text(member.phoneNumber),
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
                    Text("Whatsapp")
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
                    Text("Report")
                  ],
                ),
              ),
            ],),
            Text("Last Seen today at 12:52 AM")
          ],
        );
      },
    );
  }
}
