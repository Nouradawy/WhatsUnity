import 'package:WhatsUnity/core/theme/lightTheme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../auth/presentation/bloc/auth_cubit.dart';
import '../../../../../auth/presentation/bloc/auth_state.dart';

import '../../../../../admin/presentation/bloc/admin_cubit.dart';
import '../../../../../admin/presentation/pages/AdminDashboard/Reports.dart';
import '../../../../presentation/bloc/chat_details_cubit.dart';
import '../../../../presentation/bloc/chat_details_state.dart';


import '../../../../../../core/config/supabase.dart';
import '../../../../../../core/constants/Constants.dart';

import 'ChatMember.dart';


class ChatDetails extends StatelessWidget {
  final String compoundId;
  const ChatDetails({super.key, required this.compoundId});


  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, authState) {
        final chatMembersCount = (authState is Authenticated) ? authState
            .chatMembers.length : 0;

        return BlocBuilder<ChatDetailsCubit, ChatDetailsStates>(
          builder: (context, states) {
            return Scaffold(
              appBar: AppBar(),
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Center(child: Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                          color: Colors.white70,
                          shape: BoxShape.circle
                      ),
                      child: ClipOval(child: getCompoundPicture(context, compoundId,
                          160))
                  )
                  ),
                  SizedBox(height: 10),
                  Text("GENERAL CHAT"),
                  SizedBox(height: 5),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("Group . "),
                      Text.rich(
                        TextSpan(
                          text: '$chatMembersCount members',
                          style: context.txt.signSubtitle.copyWith(
                              color: Colors.blue),
                          recognizer:
                          TapGestureRecognizer()
                            ..onTap = () {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (BuildContext context) =>
                                        ChatMembersScreen(
                                          compoundId: compoundId,
                                        ),
                                  ));
                            },
                        ),
                      )
                    ],
                  ),
                  SizedBox(height: 10),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 10,
                    children: [
                      MaterialButton(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6.0),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        onPressed: () {},
                        child: Text("Mute Notifications"),
                      ),
                      MaterialButton(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6.0),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        onPressed: () {},
                        child: Text("Add new suggestion"),
                      )
                    ],
                  ),
                  SizedBox(height: 10),
                  Text("Description"),
                  SizedBox(height: 10),
                  Text("Notes"),
                  SizedBox(height: 15),
                  MaterialButton(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6.0),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    onPressed: () {
                      context.read<AdminCubit>().loadUserReports();
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (BuildContext context) => Reports(),
                          ));
                    },
                    child: Text("Reports"),
                  ),

                ],
              ),
            );
          },
        );
      },
    );
  }
}
