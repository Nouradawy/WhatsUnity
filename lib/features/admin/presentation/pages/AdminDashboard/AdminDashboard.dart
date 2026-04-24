import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../auth/presentation/bloc/auth_cubit.dart';
import '../../../../auth/presentation/bloc/auth_state.dart';
import '../../bloc/admin_cubit.dart';
import '../../bloc/admin_state.dart';
import '../../../../chat/presentation/widgets/chatWidget/Details/ChatMember.dart';
import 'Reports.dart';
import 'MembersManagement.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final List<String> categories = [
      "User Management",
      "Verifications Requests",
      "User Reports"
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text("Dashboard"),
      ),
      body: BlocListener<AuthCubit, AuthState>(
        listener: (context, state) {
          if ((state is CompoundSelected || state is CompoundMembersUpdated) && state is Authenticated) {
            context.read<AdminCubit>().loadCompoundMembers(state.selectedCompoundId!);
            context.read<AdminCubit>().loadUserReports();
          }
        },
        child: BlocBuilder<AuthCubit, AuthState>(
          builder: (context, authState) {
            if (authState is! Authenticated) {
              return const Center(child: CircularProgressIndicator());
            }
            final compoundId = authState.selectedCompoundId;
            if (compoundId == null) {
              return const Center(child: Text("No compound selected"));
            }
            return BlocBuilder<AdminCubit, AdminState>(
              builder: (context, state) {
                final cubit = context.read<AdminCubit>();
                return Column(
                  children: [
                    ListView.builder(
                      shrinkWrap: true,
                      itemCount: categories.length,
                      itemBuilder: (context, index) {
                        return InkWell(
                          onTap: () {
                            cubit.changeDashboardIndex(index);
                          },
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 10.0, horizontal: 20),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      categories[index],
                                      style: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.w400, fontSize: 15),
                                      textAlign: TextAlign.center,
                                    ),
                                    Icon(
                                      Icons.arrow_forward_ios,
                                      size: 20,
                                      color: Colors.grey.shade500,
                                    )
                                  ],
                                ),
                              ),
                              if (index < categories.length - 1)
                                Divider(
                                  height: 1,
                                  color: Colors.grey.shade200,
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                    if (cubit.dashboardIndex == 0)
                      Expanded(
                        child: ChatMembersScreen(
                          isAdmin: true,
                          compoundId: compoundId,
                        ),
                      ),
                    if (cubit.dashboardIndex == 1)
                      const Expanded(
                        child: MembersManagement(),
                      ),
                    if (cubit.dashboardIndex == 2)
                      const Expanded(
                        child: Reports(),
                      ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
