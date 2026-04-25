import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../services/database_helper.dart';
import 'sync_backoff.dart';
import 'sync_job_record.dart';
import 'sync_job_status.dart';
import 'sync_op_type.dart';

const int kSyncMaxAttempts = 8;

abstract class SyncJobLocalDataSource {
  Future<void> enqueue({
    required String entityType,
    required String entityId,
    required SyncOpType opType,
    required Map<String, dynamic> payload,
    String? jobId,
  });

  Future<List<SyncJobRecord>> claimDueJobs({int limit = 16});

  Future<void> markCompleted(String jobId);

  Future<void> markDeadLetter(String jobId, String error);

  Future<void> reschedule(String jobId, String error, int newAttemptCount);
}

class SyncJobLocalDataSourceImpl implements SyncJobLocalDataSource {
  SyncJobLocalDataSourceImpl(this._helper);

  final DatabaseHelper _helper;
  static const _table = 'sync_jobs';

  Future<Database> get _db => _helper.database;

  @override
  Future<void> enqueue({
    required String entityType,
    required String entityId,
    required SyncOpType opType,
    required Map<String, dynamic> payload,
    String? jobId,
  }) async {
    final db = await _db;
    final id = jobId ?? const Uuid().v4();
    final now = DateTime.now().toUtc().toIso8601String();
    await db.insert(_table, {
      'job_id': id,
      'entity_type': entityType,
      'entity_id': entityId,
      'op_type': syncOpTypeToStorage(opType),
      'payload_json': jsonEncode(payload),
      'attempts': 0,
      'status': syncJobStatusToStorage(SyncJobStatus.pending),
      'next_retry_at': null,
      'last_error': null,
      'created_at': now,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<List<SyncJobRecord>> claimDueJobs({int limit = 16}) async {
    final db = await _db;
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final rows = await db.rawQuery(
      '''
SELECT * FROM $_table
WHERE status = ?
  AND (next_retry_at IS NULL OR next_retry_at <= ?)
ORDER BY created_at ASC
LIMIT ?
''',
      [syncJobStatusToStorage(SyncJobStatus.pending), nowIso, limit],
    );
    return rows.map(_rowToRecord).toList();
  }

  @override
  Future<void> markCompleted(String jobId) async {
    final db = await _db;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.update(
      _table,
      {
        'status': syncJobStatusToStorage(SyncJobStatus.completed),
        'updated_at': now,
        'last_error': null,
        'next_retry_at': null,
      },
      where: 'job_id = ?',
      whereArgs: [jobId],
    );
  }

  @override
  Future<void> markDeadLetter(String jobId, String error) async {
    final db = await _db;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.update(
      _table,
      {
        'status': syncJobStatusToStorage(SyncJobStatus.deadLetter),
        'updated_at': now,
        'last_error': error,
      },
      where: 'job_id = ?',
      whereArgs: [jobId],
    );
  }

  @override
  Future<void> reschedule(
    String jobId,
    String error,
    int newAttemptCount,
  ) async {
    final db = await _db;
    final now = DateTime.now().toUtc();
    final wait = syncBackoffDurationForAttempt(newAttemptCount);
    final next = now.add(wait).toIso8601String();
    await db.update(
      _table,
      {
        'status': syncJobStatusToStorage(SyncJobStatus.pending),
        'attempts': newAttemptCount,
        'last_error': error,
        'next_retry_at': next,
        'updated_at': now.toIso8601String(),
      },
      where: 'job_id = ?',
      whereArgs: [jobId],
    );
  }

  SyncJobRecord _rowToRecord(Map<String, Object?> r) {
    return SyncJobRecord(
      jobId: r['job_id']! as String,
      entityType: r['entity_type']! as String,
      entityId: r['entity_id']! as String,
      opType: syncOpTypeFromString(r['op_type']! as String),
      payloadJson: r['payload_json']! as String,
      attempts: (r['attempts'] as num?)?.toInt() ?? 0,
      status: syncJobStatusFromString(r['status'] as String?),
      nextRetryAt: _parse(r['next_retry_at'] as String?),
      lastError: r['last_error'] as String?,
      createdAt:
          _parse(r['created_at'] as String?) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          _parse(r['updated_at'] as String?) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  DateTime? _parse(String? s) {
    if (s == null || s.isEmpty) return null;
    return DateTime.tryParse(s);
  }
}
