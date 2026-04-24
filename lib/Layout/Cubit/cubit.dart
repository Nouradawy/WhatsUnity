import 'package:flutter_bloc/flutter_bloc.dart';
import 'states.dart';
import '../../core/config/Enums.dart';
import '../../features/chat/presentation/widgets/chatWidget/Details/ChatMember.dart';

class AppCubit extends Cubit<AppCubitStates> {
  AppCubit() : super(AppCubitInitialStates());

  static AppCubit get(context) => BlocProvider.of(context);

  int bottomNavIndex = 0;
  int tabBarIndex = 0;

  void onProfileUpdated(ChatMember member) {
    emit(ProfileUpdateState());
  }

  void onUserRoleChanged(Roles newRole) {
    final currentLen = _bottomNavLengthForRole(newRole);
    if (bottomNavIndex >= currentLen) {
      bottomNavIndex = 0;
    }
    emit(BottomNavIndexChangeStates());
  }

  int _bottomNavLengthForRole(Roles? role) {
    if (role == Roles.manager) return 2;
    if (role == Roles.owner || role == Roles.tenant) return 5;
    return 1;
  }

  void tabBarIndexSwitcher(int index) {
    tabBarIndex = index;
    emit(TabBarIndexStates());
  }

  void bottomNavIndexChange(int index) {
    bottomNavIndex = index;
    emit(BottomNavIndexChangeStates());
  }
}
