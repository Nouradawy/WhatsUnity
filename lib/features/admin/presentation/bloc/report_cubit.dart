import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:WhatsUnity/core/config/supabase.dart';
import 'package:WhatsUnity/core/config/Enums.dart';
import 'package:WhatsUnity/core/models/ReportAUser.dart';
import 'package:WhatsUnity/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:WhatsUnity/features/auth/presentation/bloc/auth_state.dart';
import 'package:WhatsUnity/features/chat/presentation/widgets/chatWidget/Details/ChatMember.dart';

import 'report_state.dart';

class ReportCubit extends Cubit<ReportCubitState> {
  ReportCubit() : super(ReportInitialState());

  static ReportCubit get(BuildContext context) => BlocProvider.of<ReportCubit>(context);

  final TextEditingController reportDescription = TextEditingController();
  final TextEditingController issueType = TextEditingController();

  late String reportAuthorId;
  late String reportedUserId;
  late String messageId;

  int index = 0;
  ReportAUsers? reportUser;
  ReportAUserFilter filter = ReportAUserFilter.All;
  List<ReportAUsers> reportListData = [];
  List<ReportAUsers> userFilteredReports = [];

  Widget reportsList(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, authState) {
        final chatMembers = (authState is Authenticated) ? authState.chatMembers : <ChatMember>[];
        
        return ListView.builder(
          shrinkWrap: true,
          itemCount: reportListData.length,
          itemBuilder: (context, index) {
            final member = chatMembers.firstWhere(
              (m) => m.id.trim() == reportListData[index].reportedUserId,
              orElse: () => ChatMember(id: reportListData[index].reportedUserId, displayName: "Unknown", building: "", apartment: "", userState: UserState.banned, phoneNumber: "", ownerType: null),
            );
            final authorMember = chatMembers.firstWhere(
              (m) => m.id.trim() == reportListData[index].authorId,
              orElse: () => ChatMember(id: reportListData[index].authorId, displayName: "Unknown", building: "", apartment: "", userState: UserState.banned, phoneNumber: "", ownerType: null),
            );

            return Card(
              elevation: 0.5,
              margin: const EdgeInsets.symmetric(horizontal: 30, vertical: 7),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Reported User Details
                        Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              backgroundImage: member.avatarUrl != null
                                  ? NetworkImage(member.avatarUrl!)
                                  : null,
                              child: member.avatarUrl == null
                                  ? const Icon(Icons.person)
                                  : null,
                            ),
                            const SizedBox(width: 15),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(member.displayName),
                                Text("Reported ${reportListData[index].createdAt.hour.toString()}")
                              ],
                            ),
                          ],
                        ),
                        Chip(
                          visualDensity: const VisualDensity(vertical: -4),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          padding: const EdgeInsets.symmetric(horizontal: 0.0, vertical: 0),
                          label: Text(reportListData[index].state),
                          labelStyle: const TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.w900,
                          ),
                          backgroundColor: Colors.red.shade100,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 15.0),
                      child: Text(reportListData[index].description),
                    ),
                    const Divider(thickness: 0.7),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Text(
                        "Reported by ${authorMember.displayName} for ${ReportAUserType.inappropriateContent.name}",
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> reportFilterUser(String userId) async {
    await supabase.from("Report_user").select('*').eq('reportedUserId', userId);
  }

  Future<void> fileReportToUser() async {
    await supabase.from('Report_user').insert(
          ReportAUsers(
            authorId: reportAuthorId,
            createdAt: DateTime.now().toUtc(),
            reportedUserId: reportedUserId,
            state: "New",
            description: reportDescription.text,
            messageId: messageId,
            reportedFor: issueType.text,
          ).toJson(),
        );
  }

  Future<void> getReportList() async {
    final result = filter == ReportAUserFilter.All
        ? await supabase.from('Report_user').select('*')
        : await supabase.from('Report_user').select('*').eq('state', filter.name);

    reportListData = result
        .map<ReportAUsers>((element) => ReportAUsers.fromJson(element))
        .toList();
    emit(ReportGetReportsState());
  }

  void filterReportList(ReportAUserFilter newFilter) {
    filter = newFilter;
    emit(ReportFilterState());
  }
}
