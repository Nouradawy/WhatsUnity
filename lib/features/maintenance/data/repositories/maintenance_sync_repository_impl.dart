import 'dart:convert';
import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/sync/sync_engine.dart';
import '../../../../core/sync/sync_entity_types.dart';
import '../../../../core/sync/sync_job_local_data_source.dart';
import '../../../../core/sync/sync_op_type.dart';
import '../../../../core/config/Enums.dart';
import '../../domain/repositories/maintenance_sync_repository.dart';
import '../datasources/maintenance_local_data_source.dart';

class MaintenanceSyncRepositoryImpl implements MaintenanceSyncRepository {
  MaintenanceSyncRepositoryImpl({
    required MaintenanceLocalDataSource local,
    required SyncJobLocalDataSource jobStore,
    required SyncEngine engine,
  }) : _local = local,
       _jobs = jobStore,
       _engine = engine;

  final MaintenanceLocalDataSource _local;
  final SyncJobLocalDataSource _jobs;
  final SyncEngine _engine;

  @override
  Future<void> submitReportOfflineFirst({
    required String userId,
    required String title,
    required String description,
    required String category,
    required List<XFile>? files,
    required MaintenanceReportType type,
    required String? compoundId,
  }) async {
    final formattedCategory = category.isNotEmpty
        ? '${category[0].toUpperCase()}${category.substring(1)}'
        : '';

    final reportId = const Uuid().v4();
    final now = DateTime.now().toUtc();
    final nowIso = now.toIso8601String();

    final stagedPaths = <String>[];
    if (files != null && files.isNotEmpty) {
      final root = await getApplicationDocumentsDirectory();
      final dir = Directory('${root.path}/maintenance_pending/$reportId');
      await dir.create(recursive: true);
      for (final x in files) {
        final name = x.name.isNotEmpty ? x.name : p.basename(x.path);
        final dest = File('${dir.path}/$name');
        await File(x.path).copy(dest.path);
        stagedPaths.add(dest.path);
      }
    }

    final reportMap = <String, dynamic>{
      'id': reportId,
      'user_id': userId,
      'title': title,
      'description': description,
      'category': formattedCategory,
      'type': type.name,
      'status': 'New',
      'report_code': '',
      'compound_id': compoundId,
      'created_at': nowIso,
      'version': 0,
      'entity_version': 0,
      'sync_state': 'dirty',
      'local_updated_at': nowIso,
    };
    await _local.upsertReport(reportMap, force: true);

    await _jobs.enqueue(
      entityType: SyncEntityTypes.maintenanceReports,
      entityId: reportId,
      opType: SyncOpType.create,
      payload: {
        'kind': 'maintenance_report',
        'document_id': reportId,
        'user_id': userId,
        'title': title,
        'description': description,
        'category': formattedCategory,
        'type': type.name,
        'compound_id': compoundId,
        'version': 0,
      },
    );

    if (stagedPaths.isNotEmpty) {
      final attachmentId = const Uuid().v4();
      final emptyList = jsonEncode(<dynamic>[]);
      final attMap = <String, dynamic>{
        'id': attachmentId,
        'report_id': reportId,
        'compound_id': compoundId,
        'type': type.name,
        'source_url': emptyList,
        'created_at': nowIso,
        'version': 0,
        'entity_version': 0,
        'sync_state': 'dirty',
        'local_updated_at': nowIso,
      };
      await _local.upsertAttachment(attMap, force: true);

      await _jobs.enqueue(
        entityType: SyncEntityTypes.maintenanceAttachments,
        entityId: attachmentId,
        opType: SyncOpType.create,
        payload: {
          'kind': 'maintenance_attachment',
          'document_id': attachmentId,
          'report_id': reportId,
          'compound_id': compoundId,
          'type': type.name,
          'source_url_json': emptyList,
          'version': 0,
        },
      );

      for (final path in stagedPaths) {
        await _jobs.enqueue(
          entityType: SyncEntityTypes.maintenanceAttachments,
          entityId: attachmentId,
          opType: SyncOpType.uploadMedia,
          payload: {
            'attachment_id': attachmentId,
            'path': path,
            'filename_override': p.basename(path),
          },
        );
      }
    }

    _engine.kick();
  }
}
