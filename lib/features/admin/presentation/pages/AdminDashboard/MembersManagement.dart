import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../../core/config/Enums.dart';
import '../../../../auth/presentation/bloc/auth_cubit.dart';
import '../../../../auth/presentation/bloc/auth_state.dart';
import '../../bloc/admin_cubit.dart';
import '../../bloc/admin_state.dart';
import '../../widgets/members_list.dart';

class MembersManagement extends StatefulWidget {
  const MembersManagement({super.key});

  @override
  State<MembersManagement> createState() => _MembersManagementState();
}

class _MembersManagementState extends State<MembersManagement> {
  @override
  void initState() {
    super.initState();
    final authState = context.read<AuthCubit>().state;
    if (authState is Authenticated && authState.selectedCompoundId != null) {
      context.read<AdminCubit>().loadCompoundMembers(authState.selectedCompoundId!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocBuilder<AdminCubit, AdminState>(
        builder: (context, state) {
          final cubit = context.read<AdminCubit>();
          return Column(
            children: [
              Wrap(
                spacing: 8,
                children: List.generate(UserState.values.length, (i) {
                  return FilterChip(
                    label: Text(UserState.values[i].name),
                    selected: cubit.filterIndex == i,
                    onSelected: (selected) {
                      cubit.changeFilter(i);
                    },
                  );
                }),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: state is AdminLoading
                    ? const Center(child: CircularProgressIndicator())
                    : MembersList(members: cubit.filteredMembers),
              ),
            ],
          );
        },
      ),
    );
  }
}
