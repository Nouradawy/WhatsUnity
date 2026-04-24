import 'dart:convert';

// List filters: legacy Supabase used `.or()` in some codepaths; the equivalent
// is `Query.or([ <Query>... ])` when you need disjunction (not used in these calls).
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as aw_models;
import 'package:WhatsUnity/core/config/appwrite.dart';

/// APPWRITE_SCHEMA.md §2.11–2.13 — tools/provision_spec.json
const String _kReports = 'maintenance_reports';
const String _kAttachments = 'maintenance_attachments';
const String _kHistory = 'maintenance_history';

const int _kListLimit = 2000;

String _jsonEncodeSourceUrl(List<Map<String, String>> imageSources) =>
    jsonEncode(imageSources);

List<dynamic> _decodeSourceUrl(dynamic v) {
  if (v == null) return [];
  if (v is List) return v;
  if (v is String) {
    if (v.isEmpty) return [];
    try {
      final d = jsonDecode(v);
      if (d is List) return d;
    } catch (_) {}
  }
  return [];
}

Map<String, dynamic> _reportDocumentToRow(aw_models.Document doc) {
  final d = doc.data;
  return {
    'id': doc.$id,
    'user_id': d['user_id']?.toString() ?? '',
    'report_code': d['report_code']?.toString() ?? d['reportCode']?.toString() ?? '',
    'title': d['title']?.toString() ?? '',
    'description': d['description']?.toString() ?? '',
    'category': d['category']?.toString() ?? '',
    'type': d['type']?.toString() ?? '',
    'status': d['status']?.toString() ?? '',
    'compound_id': d['compound_id']?.toString(),
    'created_at': doc.$createdAt,
    'updated_at': doc.$updatedAt,
  };
}

Map<String, dynamic> _attachmentDocumentToRow(aw_models.Document doc) {
  final d = doc.data;
  return {
    'id': doc.$id,
    'report_id': d['report_id']?.toString(),
    'source_url': _decodeSourceUrl(d['source_url']),
    'compound_id': d['compound_id']?.toString(),
    'type': d['type']?.toString(),
    'created_at': doc.$createdAt,
  };
}

Map<String, dynamic> _historyDocumentToRow(aw_models.Document doc) {
  final d = doc.data;
  final createdAt = d['created_at']?.toString() ?? doc.$createdAt;
  return {
    'id': doc.$id,
    'report_id': d['report_id']?.toString() ?? '',
    'actor_id': d['actor_id']?.toString() ?? '',
    'action': d['action']?.toString() ?? '',
    'created_at': createdAt,
  };
}

abstract class MaintenanceRemoteDataSource {
  Future<Map<String, dynamic>> submitReport({
    required String userId,
    required String title,
    required String description,
    required String category,
    required String type,
    required String? compoundId,
  });

  Future<void> uploadAttachments({
    required String reportId,
    required List<Map<String, String>> imageSources,
    required String? compoundId,
    required String type,
  });

  Future<List<Map<String, dynamic>>> getReports({
    required String compoundId,
    required String type,
  });

  Future<List<Map<String, dynamic>>> getAttachments({
    required String compoundId,
    required String type,
  });

  Future<List<Map<String, dynamic>>> getReportNotes(String reportId);

  Future<void> postReportNote({
    required String reportId,
    required String actorId,
    required String action,
    required DateTime createdAt,
  });

  Future<void> updateReportStatus({
    required String reportId,
    required String status,
    required String compoundId,
    required String type,
  });
}

/// Appwrite-backed implementation (replaces Supabase).
class AppwriteMaintenanceRemoteDataSourceImpl implements MaintenanceRemoteDataSource {
  AppwriteMaintenanceRemoteDataSourceImpl({required Databases databases})
      : _databases = databases;

  final Databases _databases;

  @override
  Future<Map<String, dynamic>> submitReport({
    required String userId,
    required String title,
    required String description,
    required String category,
    required String type,
    required String? compoundId,
  }) async {
    final doc = await _databases.createDocument(
      databaseId: appwriteDatabaseId,
      collectionId: _kReports,
      documentId: ID.unique(),
      data: {
        'user_id': userId,
        'title': title,
        'description': description,
        'category': category,
        'type': type,
        if (compoundId != null) 'compound_id': compoundId,
        'version': 0,
      },
    );
    return {'id': doc.$id};
  }

  @override
  Future<void> uploadAttachments({
    required String reportId,
    required List<Map<String, String>> imageSources,
    required String? compoundId,
    required String type,
  }) async {
    await _databases.createDocument(
      databaseId: appwriteDatabaseId,
      collectionId: _kAttachments,
      documentId: ID.unique(),
      data: {
        'report_id': reportId,
        'source_url': _jsonEncodeSourceUrl(imageSources),
        'type': type,
        if (compoundId != null) 'compound_id': compoundId,
        'version': 0,
      },
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getReports({
    required String compoundId,
    required String type,
  }) async {
    final list = await _databases.listDocuments(
      databaseId: appwriteDatabaseId,
      collectionId: _kReports,
      queries: [
        Query.equal('compound_id', compoundId),
        Query.equal('type', type),
        Query.isNull('deleted_at'),
        Query.orderDesc(r'$createdAt'),
        Query.limit(_kListLimit),
      ],
    );
    return list.documents.map(_reportDocumentToRow).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getAttachments({
    required String compoundId,
    required String type,
  }) async {
    final list = await _databases.listDocuments(
      databaseId: appwriteDatabaseId,
      collectionId: _kAttachments,
      queries: [
        Query.equal('compound_id', compoundId),
        Query.equal('type', type),
        Query.isNull('deleted_at'),
        Query.orderDesc(r'$createdAt'),
        Query.limit(_kListLimit),
      ],
    );
    return list.documents.map(_attachmentDocumentToRow).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getReportNotes(String reportId) async {
    final list = await _databases.listDocuments(
      databaseId: appwriteDatabaseId,
      collectionId: _kHistory,
      queries: [
        Query.equal('report_id', reportId),
        Query.isNull('deleted_at'),
        Query.orderAsc('created_at'),
        Query.limit(_kListLimit),
      ],
    );
    return list.documents.map(_historyDocumentToRow).toList();
  }

  @override
  Future<void> postReportNote({
    required String reportId,
    required String actorId,
    required String action,
    required DateTime createdAt,
  }) async {
    await _databases.createDocument(
      databaseId: appwriteDatabaseId,
      collectionId: _kHistory,
      documentId: ID.unique(),
      data: {
        'report_id': reportId,
        'actor_id': actorId,
        'action': action,
        'created_at': createdAt.toUtc().toIso8601String(),
        'version': 0,
      },
    );
  }

  @override
  Future<void> updateReportStatus({
    required String reportId,
    required String status,
    required String compoundId,
    required String type,
  }) async {
    final existing = await _databases.getDocument(
      databaseId: appwriteDatabaseId,
      collectionId: _kReports,
      documentId: reportId,
    );
    final d = existing.data;
    final storedCompound = d['compound_id']?.toString() ?? '';
    if (storedCompound != compoundId || d['type']?.toString() != type) {
      throw StateError(
        'maintenance_reports: document $reportId does not match compound/type',
      );
    }
    await _databases.updateDocument(
      databaseId: appwriteDatabaseId,
      collectionId: _kReports,
      documentId: reportId,
      data: {'status': status},
    );
  }
}
