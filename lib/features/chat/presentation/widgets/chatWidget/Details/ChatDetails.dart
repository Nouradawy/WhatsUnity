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
                  Text(context.loc.generalChatLabel),
                  SizedBox(height: 5),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${context.loc.groupLabel} . '),
                      Text.rich(
                        TextSpan(
                          text: context.loc.membersCountLabel(chatMembersCount),
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
                        child: Text(context.loc.muteNotifications),
                      ),
                      MaterialButton(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6.0),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        onPressed: () {},
                        child: Text(context.loc.addNewSuggestion),
                      )
                    ],
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.loc.description,
                            style: context.txt.signSubtitle.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'General chat is the shared communication space for your compound. '
                            'Use it for announcements, quick coordination, and respectful neighbor discussions.',
                            style: context.txt.signSubtitle,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            context.loc.notes,
                            style: context.txt.signSubtitle.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text('• Keep messages relevant to the community.'),
                          const Text('• Be respectful and avoid personal attacks.'),
                          const Text('• Use polls and suggestions for decisions.'),
                        ],
                      ),
                    ),
                  ),
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
                    child: Text(context.loc.reports),
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
