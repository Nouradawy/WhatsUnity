import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as aw_models;
import 'package:WhatsUnity/core/config/appwrite.dart';
import '../models/admin_user_model.dart';
import '../models/user_report_model.dart';

/// provision_spec / APPWRITE_SCHEMA.md
const String _kProfiles = 'profiles';
const String _kUserApartments = 'user_apartments';
const String _kReportUser = 'report_user';

const int _kListLimit = 2000;

Map<String, dynamic> _mergedDocumentJson(aw_models.Document d) => {
      r'$id': d.$id,
      r'$createdAt': d.$createdAt,
      r'$updatedAt': d.$updatedAt,
      ...d.data,
    };

/// Appwrite-backed admin reads/writes. Method names use the `remote_` prefix (sqflite peers use `local_`).
abstract class AdminRemoteDataSource {
  /// Loads profile rows for users linked to [compoundId] via `user_apartments.compound_id`.
  /// Each profile’s `\$id` is the Appwrite user id (same as `Account` id).
  Future<List<AdminUserModel>> remote_getCompoundMembers(String compoundId);

  /// Updates `profiles.userState` for the profile document whose `\$id` is [userId].
  Future<void> remote_updateUserStatus(String userId, String status);

  Future<List<UserReportModel>> remote_getUserReports({String? status});

  /// [reportId] is the `report_user` document `\$id`.
  Future<void> remote_updateReportStatus(String reportId, String status);

  Future<void> remote_createReport(UserReportModel report);
}

class AppwriteAdminRemoteDataSourceImpl implements AdminRemoteDataSource {
  AppwriteAdminRemoteDataSourceImpl({required Databases databases})
      : _databases = databases;

  final Databases _databases;

  @override
  Future<List<AdminUserModel>> remote_getCompoundMembers(
      String compoundId) async {
    final ua = await _databases.listDocuments(
      databaseId: appwriteDatabaseId,
      collectionId: _kUserApartments,
      queries: [
        Query.equal('compound_id', compoundId),
        Query.isNull('deleted_at'),
        Query.orderDesc(r'$createdAt'),
        Query.limit(_kListLimit),
      ],
    );
    final userIds = <String>{};
    for (final doc in ua.documents) {
      final uid = doc.data['user_id']?.toString();
      if (uid != null && uid.isNotEmpty) {
        userIds.add(uid);
      }
    }
    if (userIds.isEmpty) return [];
    final idList = userIds.toList();

    final prof = await _databases.listDocuments(
      databaseId: appwriteDatabaseId,
      collectionId: _kProfiles,
      queries: [
        Query.equal(r'$id', idList),
        Query.isNull('deleted_at'),
        Query.orderDesc(r'$createdAt'),
        Query.limit(_kListLimit),
      ],
    );
    return prof.documents
        .map((d) => AdminUserModel.fromAppwriteJson(_mergedDocumentJson(d)))
        .toList();
  }

  @override
  Future<void> remote_updateUserStatus(String userId, String status) async {
    await _databases.updateDocument(
      databaseId: appwriteDatabaseId,
      collectionId: _kProfiles,
      documentId: userId,
      data: {'userState': status},
    );
  }

  @override
  Future<List<UserReportModel>> remote_getUserReports({String? status}) async {
    final list = await _databases.listDocuments(
      databaseId: appwriteDatabaseId,
      collectionId: _kReportUser,
      queries: [
        if (status != null && status != 'All') Query.equal('state', status),
        Query.isNull('deleted_at'),
        Query.orderDesc(r'$createdAt'),
        Query.limit(_kListLimit),
      ],
    );
    return list.documents
        .map((d) => UserReportModel.fromAppwriteJson(_mergedDocumentJson(d)))
        .toList();
  }

  @override
  Future<void> remote_updateReportStatus(String reportId, String status) async {
    await _databases.updateDocument(
      databaseId: appwriteDatabaseId,
      collectionId: _kReportUser,
      documentId: reportId,
      data: {'state': status},
    );
  }

  @override
  Future<void> remote_createReport(UserReportModel report) async {
    final data = report.toAppwriteJson();
    data['version'] = 0;
    await _databases.createDocument(
      databaseId: appwriteDatabaseId,
      collectionId: _kReportUser,
      documentId: ID.unique(),
      data: data,
    );
  }
}
