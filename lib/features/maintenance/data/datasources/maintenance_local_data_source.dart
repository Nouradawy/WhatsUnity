import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../core/services/database_helper.dart';
import '../../../../core/sync/lww_merge.dart';
import '../../../../core/sync/sync_metadata.dart';

/// Offline-first cache for maintenance (MIGRATION_PLAN §6).
/// Public methods use the `local_` prefix; Appwrite peers use `remote_`.
abstract class MaintenanceLocalDataSource {
  Future<void> local_upsertReport(Map<String, dynamic> row, {bool force = false});

  Future<void> local_upsertAttachment(Map<String, dynamic> row, {bool force = false});

  Future<List<Map<String, dynamic>>> local_getReports({
    required String compoundId,
    required String type,
  });

  Future<List<Map<String, dynamic>>> local_getAttachments({
    required String compoundId,
    required String type,
  });

  Future<Map<String, dynamic>?> local_getRawReport(String id);

  Future<Map<String, dynamic>?> local_getRawAttachment(String id);
}

class MaintenanceLocalDataSourceImpl implements MaintenanceLocalDataSource {
  MaintenanceLocalDataSourceImpl(this._helper);

  final DatabaseHelper _helper;
  static const _reports = 'local_maintenance_reports';
  static const _attachments = 'local_maintenance_attachments';

  Future<Database> get _db => _helper.database;

  @override
  Future<void> local_upsertReport(Map<String, dynamic> row, {bool force = false}) async {
    try {
      final id = row['id']?.toString() ?? '';
      if (id.isEmpty) return;
      if (!force) {
        final local = await local_getRawReport(id);
        if (!shouldApplyRemoteToLocal(localRow: local, remoteRow: row)) {
          return;
        }
      }
      final db = await _db;
      final record = _normalizeReport(row);
      await db.insert(
        _reports,
        record,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } on DatabaseException catch (e, st) {
      debugPrint('MaintenanceLocalDataSource.local_upsertReport: $e\n$st');
      rethrow;
    }
  }

  @override
  Future<void> local_upsertAttachment(Map<String, dynamic> row, {bool force = false}) async {
    try {
      final id = row['id']?.toString() ?? '';
      if (id.isEmpty) return;
      if (!force) {
        final local = await local_getRawAttachment(id);
        if (!shouldApplyRemoteToLocal(localRow: local, remoteRow: row)) {
          return;
        }
      }
      final db = await _db;
      final record = _normalizeAttachment(row);
      await db.insert(
        _attachments,
        record,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } on DatabaseException catch (e, st) {
      debugPrint('MaintenanceLocalDataSource.local_upsertAttachment: $e\n$st');
      rethrow;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> local_getReports({
    required String compoundId,
    required String type,
  }) async {
    try {
      final db = await _db;
      final rows = await db.query(
        _reports,
        where: 'compound_id = ? AND type = ? AND deleted_at IS NULL',
        whereArgs: [compoundId, type],
        orderBy: 'created_at DESC',
      );
      return rows.map(_reportRowToJson).toList();
    } on DatabaseException catch (e, st) {
      debugPrint('MaintenanceLocalDataSource.local_getReports: $e\n$st');
      return [];
    }
  }

  @override
  Future<List<Map<String, dynamic>>> local_getAttachments({
    required String compoundId,
    required String type,
  }) async {
    try {
      final db = await _db;
      final rows = await db.query(
        _attachments,
        where: 'compound_id = ? AND type = ? AND deleted_at IS NULL',
        whereArgs: [compoundId, type],
        orderBy: 'created_at DESC',
      );
      return rows.map(_attachmentRowToJson).toList();
    } on DatabaseException catch (e, st) {
      debugPrint('MaintenanceLocalDataSource.local_getAttachments: $e\n$st');
      return [];
    }
  }

  @override
  Future<Map<String, dynamic>?> local_getRawReport(String id) async {
    final db = await _db;
    final rows = await db.query(_reports, where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Map<String, dynamic>.from(rows.first);
  }

  @override
  Future<Map<String, dynamic>?> local_getRawAttachment(String id) async {
    final db = await _db;
    final rows = await db.query(_attachments, where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Map<String, dynamic>.from(rows.first);
  }

  Map<String, dynamic> _normalizeReport(Map<String, dynamic> raw) {
    final now = DateTime.now().toUtc().toIso8601String();
    final id = raw['id']?.toString() ?? '';
    final v = int.tryParse(raw['version']?.toString() ?? raw['entity_version']?.toString() ?? '') ?? 0;
    final syncState = raw[SyncMetadataColumns.syncState]?.toString() ?? 'clean';
    return {
      'id': id,
      'user_id': raw['user_id']?.toString() ?? '',
      'compound_id': raw['compound_id']?.toString(),
      'title': raw['title']?.toString() ?? '',
      'description': raw['description']?.toString() ?? '',
      'category': raw['category']?.toString() ?? '',
      'type': raw['type']?.toString() ?? '',
      'status': raw['status']?.toString() ?? raw['states']?.toString(),
      'report_code': raw['report_code']?.toString() ?? '',
      'created_at': raw['created_at']?.toString() ?? now,
      'updated_at': raw['updated_at']?.toString(),
      'deleted_at': raw['deleted_at']?.toString(),
      SyncMetadataColumns.version: v,
      SyncMetadataColumns.syncState: syncState,
      SyncMetadataColumns.localUpdatedAt: raw[SyncMetadataColumns.localUpdatedAt]?.toString(),
      SyncMetadataColumns.remoteUpdatedAt: raw[SyncMetadataColumns.remoteUpdatedAt]?.toString(),
      SyncMetadataColumns.lastSyncError: raw[SyncMetadataColumns.lastSyncError]?.toString(),
    };
  }

  Map<String, dynamic> _normalizeAttachment(Map<String, dynamic> raw) {
    final now = DateTime.now().toUtc().toIso8601String();
    final id = raw['id']?.toString() ?? '';
    final v = int.tryParse(raw['version']?.toString() ?? raw['entity_version']?.toString() ?? '') ?? 0;
    final syncState = raw[SyncMetadataColumns.syncState]?.toString() ?? 'clean';
    final su = raw['source_url'];
    final sourceStr = su is String
        ? su
        : jsonEncode(su ?? <dynamic>[]);
    return {
      'id': id,
      'report_id': raw['report_id']?.toString() ?? '',
      'compound_id': raw['compound_id']?.toString(),
      'type': raw['type']?.toString() ?? '',
      'source_url': sourceStr,
      'created_at': raw['created_at']?.toString() ?? now,
      'deleted_at': raw['deleted_at']?.toString(),
      SyncMetadataColumns.version: v,
      SyncMetadataColumns.syncState: syncState,
      SyncMetadataColumns.localUpdatedAt: raw[SyncMetadataColumns.localUpdatedAt]?.toString(),
      SyncMetadataColumns.remoteUpdatedAt: raw[SyncMetadataColumns.remoteUpdatedAt]?.toString(),
      SyncMetadataColumns.lastSyncError: raw[SyncMetadataColumns.lastSyncError]?.toString(),
    };
  }

  Map<String, dynamic> _reportRowToJson(Map<String, Object?> r) {
    return {
      'id': r['id']?.toString(),
      'user_id': r['user_id']?.toString() ?? '',
      'report_code': r['report_code']?.toString() ?? '',
      'title': r['title']?.toString() ?? '',
      'description': r['description']?.toString() ?? '',
      'category': r['category']?.toString() ?? '',
      'type': r['type']?.toString() ?? '',
      'status': r['status']?.toString() ?? '',
      'compound_id': r['compound_id']?.toString(),
      'created_at': r['created_at']?.toString(),
      'updated_at': r['updated_at']?.toString(),
      'version': r[SyncMetadataColumns.version],
    };
  }

  Map<String, dynamic> _attachmentRowToJson(Map<String, Object?> r) {
    final raw = r['source_url']?.toString() ?? '[]';
    List<dynamic> decoded = [];
    try {
      final d = jsonDecode(raw);
      if (d is List) decoded = d;
    } catch (_) {}
    return {
      'id': r['id']?.toString(),
      'report_id': r['report_id']?.toString(),
      'source_url': decoded,
      'created_at': r['created_at']?.toString(),
      'version': r[SyncMetadataColumns.version],
    };
  }
}
