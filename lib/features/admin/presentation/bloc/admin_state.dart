import 'package:equatable/equatable.dart';
import '../../domain/entities/admin_user.dart';
import '../../domain/entities/user_report.dart';

abstract class AdminState extends Equatable {
  const AdminState();
  @override
  List<Object?> get props => [];
}

class AdminInitial extends AdminState {}

class AdminLoading extends AdminState {}

class AdminMembersLoaded extends AdminState {
  final List<AdminUser> members;
  final List<AdminUser> filteredMembers;
  final int filterIndex;

  const AdminMembersLoaded({
    required this.members,
    required this.filteredMembers,
    required this.filterIndex,
  });

  @override
  List<Object?> get props => [members, filteredMembers, filterIndex];
}

class AdminReportsLoaded extends AdminState {
  final List<UserReport> reports;
  const AdminReportsLoaded({required this.reports});

  @override
  List<Object?> get props => [reports];
}

class AdminError extends AdminState {
  final String message;
  const AdminError(this.message);

  @override
  List<Object?> get props => [message];
}

class AdminActionSuccess extends AdminState {
  final String message;
  const AdminActionSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class AdminIndexChanged extends AdminState {
  final int index;
  const AdminIndexChanged(this.index);

  @override
  List<Object?> get props => [index];
}

class VerFilesDropToggled extends AdminState {
  final bool showVerFiles;
  const VerFilesDropToggled(this.showVerFiles);

  @override
  List<Object?> get props => [showVerFiles];
}
