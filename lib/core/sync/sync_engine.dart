import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:WhatsUnity/core/utils/app_logger.dart';

import '../media/media_upload_service.dart';
import '../../features/chat/data/datasources/chat_local_data_source.dart';
import '../../features/chat/data/datasources/chat_remote_data_source.dart';
import '../../features/chat/data/models/message_model.dart';
import '../../features/maintenance/data/datasources/maintenance_local_data_source.dart';
import '../../features/maintenance/data/datasources/maintenance_remote_data_source.dart';
import 'sync_entity_types.dart';
import 'sync_job_local_data_source.dart';
import 'sync_job_record.dart';
import 'sync_job_status.dart';
import 'sync_op_type.dart';

/// Background sync worker: drains [sync_jobs], honors connectivity, backoff, idempotency.
class SyncEngine {
  SyncEngine({
    required SyncJobLocalDataSource jobStore,
    required ChatRemoteDataSource remote,
    required ChatLocalDataSource local,
    required MediaUploadService mediaUpload,
    required MaintenanceRemoteDataSource maintenanceRemote,
    required MaintenanceLocalDataSource maintenanceLocal,
    Connectivity? connectivity,
  }) : _jobs = jobStore,
       _remote = remote,
       _local = local,
       _media = mediaUpload,
       _maintenanceRemote = maintenanceRemote,
       _maintenanceLocal = maintenanceLocal,
       _connectivity = connectivity ?? Connectivity();

  final SyncJobLocalDataSource _jobs;
  final ChatRemoteDataSource _remote;
  final ChatLocalDataSource _local;
  final MediaUploadService _media;
  final MaintenanceRemoteDataSource _maintenanceRemote;
  final MaintenanceLocalDataSource _maintenanceLocal;
  final Connectivity _connectivity;

  StreamSubscription<List<ConnectivityResult>>? _netSub;
  bool _online = true;
  bool _running = false;
  bool _started = false;

  bool get isOnline => _online;

  void start() {
    if (_started) return;
    _started = true;
    AppLogger.d("Starting SyncEngine...", tag: 'SyncEngine');
    unawaited(_refreshConnectivity());
    _netSub = _connectivity.onConnectivityChanged.listen((_) {
      AppLogger.d("Connectivity changed, refreshing...", tag: 'SyncEngine');
      unawaited(_refreshConnectivity());
    });
  }

  Future<void> dispose() async {
    AppLogger.d("Disposing SyncEngine", tag: 'SyncEngine');
    await _netSub?.cancel();
    _netSub = null;
    _started = false;
  }

  Future<void> _refreshConnectivity() async {
    try {
      final r = await _connectivity.checkConnectivity();
      _online = _resultsOnline(r);
      AppLogger.d("Online status: $_online", tag: 'SyncEngine');
    } catch (e, st) {
      AppLogger.e("Connectivity check failed", tag: 'SyncEngine', error: e, stackTrace: st);
      _online = true;
    }
    if (_online) {
      unawaited(processJobs());
    }
  }

  bool _resultsOnline(List<ConnectivityResult> results) {
    if (results.isEmpty) return false;
    return results.any(
      (e) => e != ConnectivityResult.none && e != ConnectivityResult.bluetooth,
    );
  }

  void kick() {
    unawaited(processJobs());
  }

  Future<void> processJobs() async {
    if (!_online || _running) return;
    _running = true;
    try {
      final batch = await _jobs.claimDueJobs();
      for (final job in batch) {
        if (!_online) break;
        if (job.status == SyncJobStatus.completed ||
            job.status == SyncJobStatus.deadLetter) {
          continue;
        }
        try {
          await _dispatch(job);
          await _jobs.markCompleted(job.jobId);
        } catch (e, st) {
          AppLogger.e("SyncEngine job ${job.jobId} failed", tag: 'SyncEngine', error: e, stackTrace: st);
          final nextAttempts = job.attempts + 1;
          if (nextAttempts >= kSyncMaxAttempts) {
            await _jobs.markDeadLetter(job.jobId, '$e');
          } else {
            await _jobs.reschedule(job.jobId, '$e', nextAttempts);
          }
        }
      }
    } finally {
      _running = false;
    }
  }

  Future<void> _dispatch(SyncJobRecord job) async {
    switch (job.opType) {
      case SyncOpType.create:
        await _handleCreate(job);
        break;
      case SyncOpType.uploadMedia:
        await _handleUploadMedia(job);
        break;
      case SyncOpType.update:
      case SyncOpType.delete:
        throw UnimplementedError('${job.opType} not wired yet');
    }
  }

  Future<void> _handleCreate(SyncJobRecord job) async {
    switch (job.entityType) {
      case SyncEntityTypes.messages:
        await _handleCreateMessage(job);
        break;
      case SyncEntityTypes.maintenanceReports:
        await _handleCreateMaintenanceReport(job);
        break;
      case SyncEntityTypes.maintenanceAttachments:
        await _handleCreateMaintenanceAttachment(job);
        break;
      default:
        throw UnsupportedError('CREATE entity_type=${job.entityType}');
    }
  }

  Future<void> _handleCreateMessage(SyncJobRecord job) async {
    final p = jsonDecode(job.payloadJson) as Map<String, dynamic>;
    final kind = p['kind']?.toString() ?? 'text';
    if (kind != 'text' && kind != 'poll') {
      throw UnsupportedError('Sync CREATE kind=$kind');
    }
    final documentId = p['document_id'] as String;
    Map<String, dynamic>? metaOverride;
    final mj = p['metadata_json'];
    if (mj is String && mj.trim().isNotEmpty) {
      try {
        metaOverride = Map<String, dynamic>.from(jsonDecode(mj) as Map);
      } catch (_) {}
    }
    await _remote.remote_createTextMessageWithDocumentId(
      documentId: documentId,
      text: p['text'] as String,
      channelId: p['channel_id'] as String,
      userId: p['user_id'] as String,
      nowIso: p['now_iso'] as String,
      nowMs: (p['now_ms'] as num).toInt(),
      repliedMessageId: p['replied_message_id'] as String?,
      version: (p['version'] as num?)?.toInt() ?? 0,
      metadataOverride: metaOverride,
    );
    final row = await _remote.remote_fetchMessageRow(documentId);
    final v = int.tryParse(row['version']?.toString() ?? '') ?? 0;
    row['entity_version'] = v;
    row['sync_state'] = 'clean';
    row['local_updated_at'] = DateTime.now().toUtc().toIso8601String();
    row['remote_updated_at'] =
        row['remote_updated_at']?.toString() ?? row['updated_at']?.toString();
    row['last_sync_error'] = null;
    await _local.local_insertMessage(row);
  }

  Future<void> _handleCreateMaintenanceReport(SyncJobRecord job) async {
    final p = jsonDecode(job.payloadJson) as Map<String, dynamic>;
    final documentId = p['document_id'] as String;
    await _maintenanceRemote.remote_createReportWithDocumentId(
      documentId: documentId,
      userId: p['user_id'] as String,
      title: p['title'] as String,
      description: p['description'] as String,
      category: p['category'] as String,
      type: p['type'] as String,
      compoundId: p['compound_id'] as String?,
      version: (p['version'] as num?)?.toInt() ?? 0,
    );
    final row = await _maintenanceRemote.remote_fetchReportRow(documentId);
    final v = int.tryParse(row['version']?.toString() ?? '') ?? 0;
    row['entity_version'] = v;
    row['sync_state'] = 'clean';
    row['local_updated_at'] = DateTime.now().toUtc().toIso8601String();
    row['remote_updated_at'] =
        row['remote_updated_at']?.toString() ?? row['updated_at']?.toString();
    row['last_sync_error'] = null;
    await _maintenanceLocal.local_upsertReport(row, force: true);
  }

  Future<void> _handleCreateMaintenanceAttachment(SyncJobRecord job) async {
    final p = jsonDecode(job.payloadJson) as Map<String, dynamic>;
    final documentId = p['document_id'] as String;
    await _maintenanceRemote.remote_createAttachmentWithDocumentId(
      documentId: documentId,
      reportId: p['report_id'] as String,
      sourceUrlJson: p['source_url_json'] as String,
      type: p['type'] as String,
      compoundId: p['compound_id'] as String?,
      version: (p['version'] as num?)?.toInt() ?? 0,
    );
    final row = await _maintenanceRemote.remote_fetchAttachmentRow(documentId);
    final v = int.tryParse(row['version']?.toString() ?? '') ?? 0;
    row['entity_version'] = v;
    row['sync_state'] = 'clean';
    row['local_updated_at'] = DateTime.now().toUtc().toIso8601String();
    row['remote_updated_at'] =
        row['remote_updated_at']?.toString() ?? row['updated_at']?.toString();
    row['last_sync_error'] = null;
    await _maintenanceLocal.local_upsertAttachment(row, force: true);
  }

  Future<void> _handleUploadMedia(SyncJobRecord job) async {
    switch (job.entityType) {
      case SyncEntityTypes.messages:
        await _handleUploadMediaMessage(job);
        break;
      case SyncEntityTypes.maintenanceAttachments:
        await _handleUploadMediaMaintenanceAttachment(job);
        break;
      default:
        throw UnsupportedError('UPLOAD_MEDIA entity_type=${job.entityType}');
    }
  }

  Future<void> _handleUploadMediaMessage(SyncJobRecord job) async {
    final payload = jsonDecode(job.payloadJson) as Map<String, dynamic>;
    final path = payload['path'] as String;
    final messageId = payload['message_id'] as String;
    final file = File(path);
    if (!await file.exists()) {
      throw StateError('UPLOAD_MEDIA missing file: $path');
    }
    final uploaded = await _media.uploadFromLocalPath(
      localFilePath: path,
      filenameOverride: payload['filename_override'] as String?,
      mimeType: payload['mime_type'] as String?,
    );
    final row = await _remote.remote_fetchMessageRow(messageId);
    final meta = MessageModel.normalizeMeta(row['metadata']);
    for (final e in uploaded.entries) {
      meta[e.key] = e.value;
    }
    final uri =
        uploaded['playback_url']?.toString() ??
        uploaded['url']?.toString() ??
        '';
    if (uri.isEmpty) {
      throw StateError('UPLOAD_MEDIA: no url in message upload result');
    }
    await _remote.remote_updateMessageUriAndMetadata(
      messageId: messageId,
      uri: uri,
      metadata: meta,
    );
    final fresh = await _remote.remote_fetchMessageRow(messageId);
    final v = int.tryParse(fresh['version']?.toString() ?? '') ?? 0;
    fresh['entity_version'] = v;
    fresh['sync_state'] = 'clean';
    fresh['local_updated_at'] = DateTime.now().toUtc().toIso8601String();
    fresh['remote_updated_at'] =
        fresh['remote_updated_at']?.toString() ??
            fresh['updated_at']?.toString();
    fresh['last_sync_error'] = null;
    await _local.local_insertMessage(fresh);
    try {
      await file.delete();
    } catch (_) {}
  }

  Future<void> _handleUploadMediaMaintenanceAttachment(SyncJobRecord job) async {
    final payload = jsonDecode(job.payloadJson) as Map<String, dynamic>;
    final path = payload['path'] as String;
    final attachmentId = payload['attachment_id'] as String;
    final file = File(path);
    if (!await file.exists()) {
      throw StateError('UPLOAD_MEDIA missing file: $path');
    }
    final uploaded = await _media.uploadFromLocalPath(
      localFilePath: path,
      filenameOverride: payload['filename_override'] as String?,
      mimeType: payload['mime_type'] as String?,
    );
    final url =
        uploaded['url']?.toString() ??
        uploaded['playback_url']?.toString() ??
        '';
    if (url.isEmpty) {
      throw StateError('UPLOAD_MEDIA: no url in maintenance upload result');
    }
    final name =
        payload['filename_override']?.toString() ?? p.basename(path);
    final size = uploaded['size']?.toString() ?? '${await file.length()}';
    await _maintenanceRemote.remote_appendAttachmentSourceEntry(
      attachmentId: attachmentId,
      entry: {
        'uri': url,
        'name': name,
        'size': size,
      },
    );
    final fresh = await _maintenanceRemote.remote_fetchAttachmentRow(attachmentId);
    final v = int.tryParse(fresh['version']?.toString() ?? '') ?? 0;
    fresh['entity_version'] = v;
    fresh['sync_state'] = 'clean';
    fresh['local_updated_at'] = DateTime.now().toUtc().toIso8601String();
    fresh['remote_updated_at'] =
        fresh['remote_updated_at']?.toString() ??
            fresh['updated_at']?.toString();
    fresh['last_sync_error'] = null;
    await _maintenanceLocal.local_upsertAttachment(fresh, force: true);
    try {
      await file.delete();
    } catch (_) {}
  }
}
