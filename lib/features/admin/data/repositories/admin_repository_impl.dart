import '../../domain/entities/admin_user.dart';
import '../../domain/entities/user_report.dart';
import '../../domain/repositories/admin_repository.dart';
import '../datasources/admin_remote_data_source.dart';

import '../models/user_report_model.dart';

class AdminRepositoryImpl implements AdminRepository {
  final AdminRemoteDataSource remoteDataSource;

  AdminRepositoryImpl({required this.remoteDataSource});

  @override
  Future<List<AdminUser>> getCompoundMembers(String compoundId) async {
    return await remoteDataSource.remote_getCompoundMembers(compoundId);
  }

  @override
  Future<void> updateUserStatus(String userId, String status) async {
    await remoteDataSource.remote_updateUserStatus(userId, status);
  }

  @override
  Future<List<UserReport>> getUserReports({String? status}) async {
    return await remoteDataSource.remote_getUserReports(status: status);
  }

  @override
  Future<void> updateReportStatus(String reportId, String status) async {
    await remoteDataSource.remote_updateReportStatus(reportId, status);
  }

  @override
  Future<void> createReport(UserReport report) async {
    final model = UserReportModel(
      id: report.id,
      authorId: report.authorId,
      createdAt: report.createdAt,
      reportedUserId: report.reportedUserId,
      state: report.state,
      description: report.description,
      messageId: report.messageId,
      reportedFor: report.reportedFor,
      compoundId: report.compoundId,
    );
    await remoteDataSource.remote_createReport(model);
  }
}
