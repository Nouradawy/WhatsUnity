import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/config/Enums.dart';

import '../../domain/entities/admin_user.dart';
import '../../domain/entities/user_report.dart';
import '../../domain/repositories/admin_repository.dart';
import 'admin_state.dart';

class AdminCubit extends Cubit<AdminState> {
  final AdminRepository adminRepository;

  AdminCubit({required this.adminRepository}) : super(AdminInitial());

  int dashboardIndex = 0;
  int filterIndex = 0;
  bool showVerFiles = true;
  List<AdminUser> allMembers = [];
  List<AdminUser> filteredMembers = [];
  List<UserReport> userReports = [];

  void changeDashboardIndex(int index) {
    dashboardIndex = index;
    emit(AdminIndexChanged(dashboardIndex));
  }

  void toggleVerFiles() {
    showVerFiles = !showVerFiles;
    emit(VerFilesDropToggled(showVerFiles));
  }

  /// [compoundId] is the Appwrite `compounds` document `\$id` (string FK everywhere).
  Future<void> fetchCompoundMembers(String compoundId) async {
    emit(AdminLoading());
    try {
      allMembers = await adminRepository.getCompoundMembers(compoundId);
      _filterMembers();
    } catch (e) {
      emit(AdminError(e.toString()));
    }
  }

  void changeFilter(int index) {
    filterIndex = index;
    _filterMembers();
  }

  void _filterMembers() {
    final status = UserState.values[filterIndex].name;
    filteredMembers = allMembers.where((member) => member.userState.toLowerCase() == status.toLowerCase()).toList();
    emit(AdminMembersLoaded(
      members: allMembers,
      filteredMembers: filteredMembers,
      filterIndex: filterIndex,
    ));
  }

  Future<void> updateUserStatus(
      String userId, UserState status, String compoundId) async {
    try {
      await adminRepository.updateUserStatus(userId, status.name);
      emit(AdminActionSuccess('User status updated to ${status.name}'));
      await fetchCompoundMembers(compoundId);
    } catch (e) {
      emit(AdminError(e.toString()));
    }
  }

  Future<void> loadUserReports({ReportAUserFilter? filter}) async {
    emit(AdminLoading());
    try {
      userReports = await adminRepository.getUserReports(status: filter?.name);
      emit(AdminReportsLoaded(reports: userReports));
    } catch (e) {
      emit(AdminError(e.toString()));
    }
  }

  /// [reportId] is the `report_user` document `\$id`.
  Future<void> updateReportStatus(String reportId, String status) async {
    try {
      await adminRepository.updateReportStatus(reportId, status);
      emit(AdminActionSuccess('Report status updated to $status'));
      await loadUserReports();
    } catch (e) {
      emit(AdminError(e.toString()));
    }
  }

  Future<void> createReport(UserReport report) async {
    emit(AdminLoading());
    try {
      await adminRepository.createReport(report);
      emit(AdminActionSuccess('Report submitted successfully'));
    } catch (e) {
      emit(AdminError(e.toString()));
    }
  }
}
