import 'dart:convert';

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

List<Map<String, dynamic>> _verFilesFrom(dynamic v) {
  if (v == null) return [];
  if (v is List) {
    return v
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }
  if (v is String) {
    if (v.isEmpty) return [];
    try {
      final d = jsonDecode(v);
      if (d is List) {
        return d
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
    } catch (_) {}
  }
  return [];
}

Map<String, dynamic> _profileToAdminMap(aw_models.Document doc) {
  final d = doc.data;
  return {
    'id': doc.$id,
    'phone_number': d['phone_number'],
    'updated_at': doc.$updatedAt,
    'owner_type': d['owner_type'],
    'userState': d['userState'],
    'actionTakenBy': d['actionTakenBy'],
    'verFiles': _verFilesFrom(d['verFiles']),
  };
}

Map<String, dynamic> _reportUserToMap(aw_models.Document doc) {
  final d = doc.data;
  return {
    'id': doc.$id,
    'authorId': d['authorId']?.toString() ?? '',
    'createdAt': d['createdAt']?.toString() ?? doc.$createdAt,
    'reportedUserId': d['reportedUserId']?.toString() ?? '',
    'state': d['state']?.toString() ?? '',
    'description': d['description']?.toString() ?? '',
    'messageId': d['messageId']?.toString() ?? '',
    'reportedFor': d['reportedFor']?.toString() ?? '',
  };
}

abstract class AdminRemoteDataSource {
  Future<List<AdminUserModel>> getCompoundMembers(String compoundId);
  Future<void> updateUserStatus(String userId, String status);
  Future<List<UserReportModel>> getUserReports({String? status});
  Future<void> updateReportStatus(String reportId, String status);
  Future<void> createReport(UserReportModel report);
}

class AppwriteAdminRemoteDataSourceImpl implements AdminRemoteDataSource {
  AppwriteAdminRemoteDataSourceImpl({required Databases databases})
      : _databases = databases;

  final Databases _databases;

  @override
  Future<List<AdminUserModel>> getCompoundMembers(String compoundId) async {
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
        .map((d) => AdminUserModel.fromJson(_profileToAdminMap(d)))
        .toList();
  }

  @override
  Future<void> updateUserStatus(String userId, String status) async {
    await _databases.updateDocument(
      databaseId: appwriteDatabaseId,
      collectionId: _kProfiles,
      documentId: userId,
      data: {'userState': status},
    );
  }

  @override
  Future<List<UserReportModel>> getUserReports({String? status}) async {
    // Order by $createdAt (same semantic as Supabase "newest first").
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
        .map((d) => UserReportModel.fromJson(_reportUserToMap(d)))
        .toList();
  }

  @override
  Future<void> updateReportStatus(String reportId, String status) async {
    await _databases.updateDocument(
      databaseId: appwriteDatabaseId,
      collectionId: _kReportUser,
      documentId: reportId,
      data: {'state': status},
    );
  }

  @override
  Future<void> createReport(UserReportModel report) async {
    final data = <String, dynamic>{
      'authorId': report.authorId,
      'createdAt': report.createdAt.toUtc().toIso8601String(),
      'reportedUserId': report.reportedUserId,
      'state': report.state,
      'description': report.description,
      'messageId': report.messageId,
      'reportedFor': report.reportedFor,
      'version': 0,
    };
    await _databases.createDocument(
      databaseId: appwriteDatabaseId,
      collectionId: _kReportUser,
      documentId: ID.unique(),
      data: data,
    );
  }
}
