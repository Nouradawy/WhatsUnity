import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../Layout/Cubit/cubit.dart';
import '../../../../Layout/Cubit/states.dart';
import '../../../../core/di/app_services.dart';
import '../../../../core/config/Enums.dart';
import '../../../admin/presentation/pages/AdminDashboard/AdminDashboard.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../auth/presentation/pages/gatekeeper_user_page.dart';
import '../../../chat/presentation/pages/building_chat_page.dart';
import '../../../chat/presentation/bloc/mention_notification_cubit.dart';
import '../../../profile/presentation/pages/profile_page.dart';


class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  String? _lastMentionContextKey;
  int? _lastBottomNavIndex;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppServices.messageNotificationLifecycleService.initialize();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    AppServices.messageNotificationLifecycleService.updateLifecycleState(state);
    super.didChangeAppLifecycleState(state);
  }

  void _syncMentionNotifications({
    required AuthState authState,
    required Roles? role,
    required int bottomNavIndex,
  }) {
    final mentionCubit = context.read<MentionNotificationCubit>();
    if (authState is! Authenticated) {
      if (_lastMentionContextKey != null) {
        _lastMentionContextKey = null;
        _lastBottomNavIndex = null;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          mentionCubit.stop();
          AppServices.messageNotificationLifecycleService.stop();
          unawaited(AppServices.pushTargetRegistrationService.stop());
        });
      }
      return;
    }

    final contextKey =
        '${authState.user.id}_${authState.selectedCompoundId}_${authState.currentUser?.building}_${authState.timestamp}';
    final isChatsTab = role != Roles.manager && bottomNavIndex == 1;
    final shouldMarkSeen = isChatsTab && _lastBottomNavIndex != 1;
    final shouldStart = _lastMentionContextKey != contextKey;

    _lastMentionContextKey = contextKey;
    _lastBottomNavIndex = bottomNavIndex;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (shouldStart) {
        mentionCubit.startForAuthState(authState);
        AppServices.messageNotificationLifecycleService.startForAuthState(
          authState,
        );
        AppServices.pushTargetRegistrationService.startForAuthState(authState);
      }
      if (shouldMarkSeen) {
        mentionCubit.markBuildingMentionsAsSeen(authState);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    context.read<MentionNotificationCubit>().stop();
    AppServices.messageNotificationLifecycleService.stop();
    unawaited(AppServices.pushTargetRegistrationService.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {


    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, authState) {
        return BlocBuilder<AppCubit, AppCubitStates>(
          // Only rebuild when something that affects the screens list or nav bar
          // selection actually changes. TabBarIndexStates and ProfileUpdateState
          // must NOT trigger a rebuild here — they cause the IndexedStack to
          // momentarily re-evaluate all screens, which can destroy GeneralChat
          // mid-animation and trigger the SliverAnimatedList assertion.
          buildWhen: (prev, curr) =>
              curr is BottomNavIndexChangeStates || curr is AppCubitInitialStates,
          builder: (context, states) {
            final cubit = AppCubit.get(context);
            final Roles? role = (authState is Authenticated) ? authState.role : null;
            _syncMentionNotifications(
              authState: authState,
              role: role,
              bottomNavIndex: cubit.bottomNavIndex,
            );

            // ALWAYS mount BuildingChat — never swap it with SizedBox.shrink().
            // IndexedStack keeps every child alive in the tree and only paints
            // the one at [index]. Swapping BuildingChat ↔ SizedBox on every tab
            // switch destroyed/recreated GeneralChat on each transition, which:
            //   1. Fired the SliverAnimatedList assertion during disposal.
            //   2. Corrupted the IndexedStack render frame and blanked tabs 2/3.
            final List<Widget> screens = [
              GatekeeperScreen(index: role == Roles.manager ? 0 : 1),
              if (role != Roles.manager) const BuildingChat(),
              ProfilePage(),
              if (role == Roles.admin) const AdminDashboard(),
            ];
            final safeIndex = cubit.bottomNavIndex >= screens.length
                ? 0
                : cubit.bottomNavIndex;
            if (safeIndex != cubit.bottomNavIndex) {
              Future.microtask(() => cubit.bottomNavIndexChange(safeIndex));
            }

            return Scaffold(
              // Let the body shrink with the keyboard so chat/composer stay above it.
              // `false` caused a full-height body + manual padding hacks and a visible gap.
              resizeToAvoidBottomInset: true,
              bottomNavigationBar: BottomNavigationBar(
                  type: BottomNavigationBarType.fixed,
                  currentIndex: cubit.bottomNavIndex,
                  onTap: (index) => cubit.bottomNavIndexChange(index),
                  items: <BottomNavigationBarItem>[

                    BottomNavigationBarItem(
                      icon: BlocBuilder<MentionNotificationCubit,
                          MentionNotificationState>(
                        buildWhen: (previous, current) =>
                            previous.unreadGeneralMentionCount !=
                            current.unreadGeneralMentionCount,
                        builder: (context, mentionState) {
                          final unreadCount =
                              mentionState.unreadGeneralMentionCount;
                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              const FaIcon(FontAwesomeIcons.house, size: 18),
                              if (unreadCount > 0 && cubit.bottomNavIndex != 0)
                                Positioned(
                                  right: -8,
                                  top: -8,
                                  child: Container(
                                    constraints: const BoxConstraints(
                                      minWidth: 16,
                                      minHeight: 16,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade600,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      unreadCount > 99
                                          ? '99+'
                                          : unreadCount.toString(),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                      label: "Home",
                    ),
                    if (role != Roles.manager)
                      BottomNavigationBarItem(
                        icon: BlocBuilder<MentionNotificationCubit,
                            MentionNotificationState>(
                          buildWhen: (previous, current) =>
                              previous.unreadBuildingMentionCount !=
                              current.unreadBuildingMentionCount,
                          builder: (context, mentionState) {
                            final unreadCount =
                                mentionState.unreadBuildingMentionCount;
                            return Stack(
                              clipBehavior: Clip.none,
                              children: [
                                const FaIcon(
                                  FontAwesomeIcons.solidMessage,
                                  size: 18,
                                ),
                                if (unreadCount > 0)
                                  Positioned(
                                    right: -8,
                                    top: -8,
                                    child: Container(
                                      constraints: const BoxConstraints(
                                        minWidth: 16,
                                        minHeight: 16,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade600,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        unreadCount > 99
                                            ? '99+'
                                            : unreadCount.toString(),
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                        label: "Chats",
                      ),
                    // BottomNavigationBarItem(
                    //     icon: Icon(Icons.handyman_outlined),
                    //     label: "Services"
                    // ),
                    // BottomNavigationBarItem(
                    //     icon: Icon(Icons.announcement_outlined),
                    //     label: "announcements"
                    // ),
                    BottomNavigationBarItem(
                        icon: FaIcon(FontAwesomeIcons.userLarge
                            , size: 19),
                        label: "Profile"
                    ),
                    if (role == Roles.admin)
                      BottomNavigationBarItem(
                          icon: FaIcon(FontAwesomeIcons.userTie
                              , size: 19),
                          label: "Admin dashboard"
                      ),
                  ]),
              body: IndexedStack(
                index: safeIndex,
                children: screens,
              ),
            );
          }
        );
      }
    );
  }
}
