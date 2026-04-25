import 'dart:async';

import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/Enums.dart';
import '../../../../core/models/MaintenanceReport.dart';
import '../../domain/repositories/maintenance_repository.dart';
import '../../domain/repositories/maintenance_sync_repository.dart';
import '../datasources/maintenance_local_data_source.dart';
import '../datasources/maintenance_remote_data_source.dart';

class MaintenanceRepositoryImpl implements MaintenanceRepository {
  MaintenanceRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.syncRepository,
    required this.supabaseClient,
  });

  final MaintenanceRemoteDataSource remoteDataSource;
  final MaintenanceLocalDataSource localDataSource;
  final MaintenanceSyncRepository syncRepository;
  final SupabaseClient supabaseClient;

  @override
  Future<void> submitReport({
    required String title,
    required String description,
    required String category,
    required List<XFile>? files,
    required MaintenanceReportType type,
    required String? compoundId,
  }) async {
    final userId = supabaseClient.auth.currentUser?.id;
    if (userId == null) return;

    await syncRepository.submitReportOfflineFirst(
      userId: userId,
      title: title,
      description: description,
      category: category,
      files: files,
      type: type,
      compoundId: compoundId,
    );
  }

  Future<void> _mergeRemoteReports(String compoundId, String type) async {
    try {
      final remote = await remoteDataSource.getReports(
        compoundId: compoundId,
        type: type,
      );
      for (final r in remote) {
        await localDataSource.upsertReport(r);
      }
    } catch (_) {}
  }

  Future<void> _mergeRemoteAttachments(String compoundId, String type) async {
    try {
      final remote = await remoteDataSource.getAttachments(
        compoundId: compoundId,
        type: type,
      );
      for (final a in remote) {
        await localDataSource.upsertAttachment(a);
      }
    } catch (_) {}
  }

  @override
  Future<List<MaintenanceReports>> getReports({
    required String compoundId,
    required MaintenanceReportType type,
  }) async {
    var local = await localDataSource.getReports(
      compoundId: compoundId,
      type: type.name,
    );
    if (local.isEmpty) {
      await _mergeRemoteReports(compoundId, type.name);
      local = await localDataSource.getReports(
        compoundId: compoundId,
        type: type.name,
      );
    } else {
      unawaited(_mergeRemoteReports(compoundId, type.name));
    }
    return local.map(MaintenanceReports.fromJson).toList();
  }

  @override
  Future<List<MaintenanceReportsAttachments>> getAttachments({
    required String compoundId,
    required MaintenanceReportType type,
  }) async {
    var local = await localDataSource.getAttachments(
      compoundId: compoundId,
      type: type.name,
    );
    if (local.isEmpty) {
      await _mergeRemoteAttachments(compoundId, type.name);
      local = await localDataSource.getAttachments(
        compoundId: compoundId,
        type: type.name,
      );
    } else {
      unawaited(_mergeRemoteAttachments(compoundId, type.name));
    }
    return local.map(MaintenanceReportsAttachments.fromJson).toList();
  }

  @override
  Future<List<MaintenanceReportsHistory>> getReportNotes(String reportId) async {
    final data = await remoteDataSource.getReportNotes(reportId);
    return data.map(MaintenanceReportsHistory.fromJson).toList();
  }

  @override
  Future<void> postReportNote({
    required String reportId,
    required String actorId,
    required String action,
  }) async {
    await remoteDataSource.postReportNote(
      reportId: reportId,
      actorId: actorId,
      action: action,
      createdAt: DateTime.now().toUtc(),
    );
  }

  @override
  Future<void> updateReportStatus({
    required String reportId,
    required String status,
    required String compoundId,
    required MaintenanceReportType type,
  }) async {
    await remoteDataSource.updateReportStatus(
      reportId: reportId,
      status: status,
      compoundId: compoundId,
      type: type.name,
    );
    try {
      final row = await remoteDataSource.fetchReportRow(reportId);
      final v = int.tryParse(row['version']?.toString() ?? '') ?? 0;
      row['entity_version'] = v;
      row['sync_state'] = 'clean';
      row['local_updated_at'] = DateTime.now().toUtc().toIso8601String();
      row['remote_updated_at'] =
          row['remote_updated_at']?.toString() ?? row['updated_at']?.toString();
      await localDataSource.upsertReport(row, force: true);
    } catch (_) {}
  }
}
