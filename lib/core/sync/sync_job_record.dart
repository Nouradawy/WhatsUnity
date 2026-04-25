import 'sync_job_status.dart';
import 'sync_op_type.dart';

class SyncJobRecord {
  const SyncJobRecord({
    required this.jobId,
    required this.entityType,
    required this.entityId,
    required this.opType,
    required this.payloadJson,
    required this.attempts,
    required this.status,
    this.nextRetryAt,
    this.lastError,
    required this.createdAt,
    required this.updatedAt,
  });

  final String jobId;
  final String entityType;
  final String entityId;
  final SyncOpType opType;
  final String payloadJson;
  final int attempts;
  final SyncJobStatus status;
  final DateTime? nextRetryAt;
  final String? lastError;
  final DateTime createdAt;
  final DateTime updatedAt;
}
