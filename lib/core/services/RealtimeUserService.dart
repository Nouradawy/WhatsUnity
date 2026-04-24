import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../Layout/Cubit/cubit.dart';
import '../../features/auth/presentation/bloc/auth_cubit.dart';
import '../../features/auth/presentation/bloc/auth_state.dart';
import '../../features/chat/presentation/bloc/chat_details_cubit.dart';
import '../../features/chat/presentation/widgets/chatWidget/Details/ChatMember.dart';
import '../config/Enums.dart';
import '../config/supabase.dart';


class RealtimeUserService {
  RealtimeUserService._();
  static final RealtimeUserService instance = RealtimeUserService._();

  RealtimeChannel? _profileChannel;
  RealtimeChannel? _rolesChannel;

  void init(BuildContext context) {
    final authState = context.read<AuthCubit>().state;
    if (authState is! Authenticated) return;
    final userId = authState.user.id;

    // \[1] Listen on profiles table for this user
    _profileChannel ??= supabase.channel('public:profiles:$userId')
      ..onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'profiles',
        filter: PostgresChangeFilter(column: 'id', type:PostgresChangeFilterType.eq, value:userId),
        callback: (payload) {
          _handleProfileUpdate(context, payload);
        },
      )
      ..subscribe();

    // \[2] Listen on user_roles (or equivalent) for this user
    _rolesChannel ??= supabase.channel('public:user_roles:$userId')
      ..onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'user_roles',
        filter: PostgresChangeFilter(column: 'user_id', type:PostgresChangeFilterType.eq, value:userId),
        callback: (payload) {
          _handleRoleUpdate(context, payload);
        },
      )
      ..subscribe();
  }

  void dispose() {
    _profileChannel?.unsubscribe();
    _rolesChannel?.unsubscribe();
    _profileChannel = null;
    _rolesChannel = null;
  }

  // \[A] Handle profile row change
  void _handleProfileUpdate(BuildContext context, PostgresChangePayload payload) {
    if (!context.mounted) return;
    final newRecord = payload.newRecord;
    debugPrint(newRecord['userState']);
    final authCubit = context.read<AuthCubit>();
    final authState = authCubit.state;
    if (authState is! Authenticated) return;
    final currentUserMember = authState.currentUser;
    if (currentUserMember == null) return;

    final appCubit = AppCubit.get(context);
    // 1) Find existing member by user id (adjust to your storage)
    final String userId = newRecord['id']?.toString() ?? '';
    debugPrint(newRecord['userState']);
    final ChatMember existing = authState.chatMembers.firstWhere((m) => m?.id == userId);
    final updatedMember = ChatMember.fromJson(newRecord);
    ChatMember member;

    member = existing.copyWithProfileUpdate(newRecord);
    authCubit.updateMember(member);
    appCubit.onProfileUpdated(member);
    ChatDetailsCubit.get(context).onProfileUpdated(member);
  }

  // \[B] Handle role change row
  void _handleRoleUpdate(BuildContext context, PostgresChangePayload payload) {
    if (!context.mounted) return;
    final newRecord = payload.newRecord;

    final int? newRoleId = newRecord['role_id'] as int?;
    if (newRoleId == null) return;

    Roles? newUserRole;
    // Update global role
    if (newRoleId > 0 && newRoleId <= Roles.values.length) {
      newUserRole = Roles.values[newRoleId - 1];
    }
    if (newUserRole == null) return;

    debugPrint("current userRole on update :${newUserRole.name} ");
    final appCubit = AppCubit.get(context);
    final authCubit = context.read<AuthCubit>();
    
    authCubit.updateRole(newUserRole);
    // If you want to reset bottom nav index or screens, do it through AppCubit
    appCubit.onUserRoleChanged(newUserRole);
  }
}