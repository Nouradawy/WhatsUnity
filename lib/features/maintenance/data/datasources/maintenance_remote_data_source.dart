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
  final v = int.tryParse(d['version']?.toString() ?? '') ?? 0;
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
    'version': v,
    'remote_updated_at': doc.$updatedAt,
  };
}

Map<String, dynamic> _attachmentDocumentToRow(aw_models.Document doc) {
  final d = doc.data;
  final v = int.tryParse(d['version']?.toString() ?? '') ?? 0;
  return {
    'id': doc.$id,
    'report_id': d['report_id']?.toString(),
    'source_url': _decodeSourceUrl(d['source_url']),
    'compound_id': d['compound_id']?.toString(),
    'type': d['type']?.toString(),
    'created_at': doc.$createdAt,
    'version': v,
    'remote_updated_at': doc.$updatedAt,
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
  /// Creates a maintenance report remotely; returned `id` is the report document `$id`.
  Future<Map<String, dynamic>> remote_submitReport({
    required String userId,
    required String title,
    required String description,
    required String category,
    required String type,
    required String? compoundId,
  });

  Future<void> remote_uploadAttachments({
    required String reportId,
    required List<Map<String, String>> imageSources,
    required String? compoundId,
    required String type,
  });

  Future<List<Map<String, dynamic>>> remote_getReports({
    required String compoundId,
    required String type,
  });

  Future<List<Map<String, dynamic>>> remote_getAttachments({
    required String compoundId,
    required String type,
  });

  Future<List<Map<String, dynamic>>> remote_getReportNotes(String reportId);

  Future<void> remote_postReportNote({
    required String reportId,
    required String actorId,
    required String action,
    required DateTime createdAt,
  });

  Future<void> remote_updateReportStatus({
    required String reportId,
    required String status,
    required String compoundId,
    required String type,
  });

  /// Idempotent create with client-chosen [documentId] (offline-first).
  Future<void> remote_createReportWithDocumentId({
    required String documentId,
    required String userId,
    required String title,
    required String description,
    required String category,
    required String type,
    required String? compoundId,
    int version = 0,
  });

  Future<void> remote_createAttachmentWithDocumentId({
    required String documentId,
    required String reportId,
    required String sourceUrlJson,
    required String type,
    required String? compoundId,
    int version = 0,
  });

  Future<Map<String, dynamic>> remote_fetchReportRow(String reportId);

  Future<Map<String, dynamic>> remote_fetchAttachmentRow(String attachmentId);

  /// Append one file map to `source_url` JSON array and bump `version`.
  Future<void> remote_appendAttachmentSourceEntry({
    required String attachmentId,
    required Map<String, String> entry,
  });
}

/// Appwrite-backed implementation (replaces Supabase).
class AppwriteMaintenanceRemoteDataSourceImpl implements MaintenanceRemoteDataSource {
  AppwriteMaintenanceRemoteDataSourceImpl({required Databases databases})
      : _databases = databases;

  final Databases _databases;

  @override
  Future<Map<String, dynamic>> remote_submitReport({
    required String userId,
    required String title,
    required String description,
    required String category,
    required String type,
    required String? compoundId,
  }) async {
    final id = ID.unique();
    await remote_createReportWithDocumentId(
      documentId: id,
      userId: userId,
      title: title,
      description: description,
      category: category,
      type: type,
      compoundId: compoundId,
      version: 0,
    );
    return {'id': id};
  }

  @override
  Future<void> remote_createReportWithDocumentId({
    required String documentId,
    required String userId,
    required String title,
    required String description,
    required String category,
    required String type,
    required String? compoundId,
    int version = 0,
  }) async {
    try {
      await _databases.createDocument(
        databaseId: appwriteDatabaseId,
        collectionId: _kReports,
        documentId: documentId,
        data: {
          'user_id': userId,
          'title': title,
          'description': description,
          'category': category,
          'type': type,
          'status': 'New',
          if (compoundId != null) 'compound_id': compoundId,
          'version': version,
        },
      );
    } on AppwriteException catch (e) {
      if (e.code == 409 ||
          '${e.message}'.toLowerCase().contains('already exists')) {
        return;
      }
      rethrow;
    }
  }

  @override
  Future<void> remote_createAttachmentWithDocumentId({
    required String documentId,
    required String reportId,
    required String sourceUrlJson,
    required String type,
    required String? compoundId,
    int version = 0,
  }) async {
    try {
      await _databases.createDocument(
        databaseId: appwriteDatabaseId,
        collectionId: _kAttachments,
        documentId: documentId,
        data: {
          'report_id': reportId,
          'source_url': sourceUrlJson,
          'type': type,
          if (compoundId != null) 'compound_id': compoundId,
          'version': version,
        },
      );
    } on AppwriteException catch (e) {
      if (e.code == 409 ||
          '${e.message}'.toLowerCase().contains('already exists')) {
        return;
      }
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>> remote_fetchReportRow(String reportId) async {
    final doc = await _databases.getDocument(
      databaseId: appwriteDatabaseId,
      collectionId: _kReports,
      documentId: reportId,
    );
    return _reportDocumentToRow(doc);
  }

  @override
  Future<Map<String, dynamic>> remote_fetchAttachmentRow(String attachmentId) async {
    final doc = await _databases.getDocument(
      databaseId: appwriteDatabaseId,
      collectionId: _kAttachments,
      documentId: attachmentId,
    );
    return _attachmentDocumentToRow(doc);
  }

  @override
  Future<void> remote_appendAttachmentSourceEntry({
    required String attachmentId,
    required Map<String, String> entry,
  }) async {
    final existing = await _databases.getDocument(
      databaseId: appwriteDatabaseId,
      collectionId: _kAttachments,
      documentId: attachmentId,
    );
    final d = existing.data;
    final list = _decodeSourceUrl(d['source_url']);
    final merged = <Map<String, dynamic>>[];
    for (final e in list) {
      if (e is Map) merged.add(Map<String, dynamic>.from(e));
    }
    merged.add(Map<String, dynamic>.from(entry));
    final v = int.tryParse(d['version']?.toString() ?? '') ?? 0;
    await _databases.updateDocument(
      databaseId: appwriteDatabaseId,
      collectionId: _kAttachments,
      documentId: attachmentId,
      data: {
        'source_url': jsonEncode(merged),
        'version': v + 1,
      },
    );
  }

  @override
  Future<void> remote_uploadAttachments({
    required String reportId,
    required List<Map<String, String>> imageSources,
    required String? compoundId,
    required String type,
  }) async {
    final id = ID.unique();
    await remote_createAttachmentWithDocumentId(
      documentId: id,
      reportId: reportId,
      sourceUrlJson: _jsonEncodeSourceUrl(imageSources),
      type: type,
      compoundId: compoundId,
      version: 0,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> remote_getReports({
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
  Future<List<Map<String, dynamic>>> remote_getAttachments({
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
  Future<List<Map<String, dynamic>>> remote_getReportNotes(String reportId) async {
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
  Future<void> remote_postReportNote({
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
  Future<void> remote_updateReportStatus({
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
    final v = int.tryParse(existing.data['version']?.toString() ?? '') ?? 0;
    await _databases.updateDocument(
      databaseId: appwriteDatabaseId,
      collectionId: _kReports,
      documentId: reportId,
      data: {
        'status': status,
        'version': v + 1,
      },
    );
  }
}
