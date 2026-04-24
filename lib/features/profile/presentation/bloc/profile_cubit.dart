import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/config/Enums.dart';
import 'profile_state.dart';

class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit() : super(ProfileInitial());

  ProfileSection? activeSection = ProfileSection.account;
  Map<ProfileSection, int?> activeIndexBySection = {
    ProfileSection.account: 0,
    ProfileSection.preferences: null,
    ProfileSection.support: null,
  };

  bool isOtpVisible = false;

  void toggleSection(ProfileSection section, int index) {
    if (activeSection == section && activeIndexBySection[section] == index) {
      activeSection = null;
      activeIndexBySection[section] = null;
    } else {
      activeSection = section;
      activeIndexBySection[section] = index;
    }
    emit(ProfileDropdownToggled(section, index));
  }

  bool isSectionActive(ProfileSection section, int index) {
    return activeSection == section && activeIndexBySection[section] == index;
  }

  void setOtpVisibility(bool visible) {
    isOtpVisible = visible;
    emit(ProfileOtpVisibilityChanged(visible));
  }
}
