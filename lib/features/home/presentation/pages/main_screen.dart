import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../Layout/Cubit/cubit.dart';
import '../../../../Layout/Cubit/states.dart';
import '../../../../core/config/Enums.dart';
import '../../../admin/presentation/pages/AdminDashboard/AdminDashboard.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../auth/presentation/pages/gatekeeper_user_page.dart';
import '../../../chat/presentation/pages/building_chat_page.dart';
import '../../../profile/presentation/pages/profile_page.dart';


class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

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
              if (role == Roles.admin) AdminDashboard(),
            ];

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
                        icon: FaIcon(FontAwesomeIcons.house, size: 18),
                        label: "Home"
                    ),
                    if (role != Roles.manager)
                      BottomNavigationBarItem(
                          icon: FaIcon(FontAwesomeIcons.solidMessage, size: 18),
                          label: "Chats"
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
                index: cubit.bottomNavIndex,
                children: screens,
              ),
            );
          }
        );
      }
    );
  }
}
