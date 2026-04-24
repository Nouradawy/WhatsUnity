import 'package:equatable/equatable.dart';
import '../../../../core/config/Enums.dart';

abstract class ProfileState extends Equatable {
  const ProfileState();

  @override
  List<Object?> get props => [];
}

class ProfileInitial extends ProfileState {}

class ProfileDropdownToggled extends ProfileState {
  final ProfileSection section;
  final int index;

  const ProfileDropdownToggled(this.section, this.index);

  @override
  List<Object?> get props => [section, index];
}

class ProfileOtpVisibilityChanged extends ProfileState {
  final bool isVisible;

  const ProfileOtpVisibilityChanged(this.isVisible);

  @override
  List<Object?> get props => [isVisible];
}
