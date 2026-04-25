import 'package:image_picker/image_picker.dart';

import '../../../../core/config/Enums.dart';

/// Local-first maintenance submit: SQLite + [sync_jobs] + [SyncEngine].
abstract class MaintenanceSyncRepository {
  Future<void> submitReportOfflineFirst({
    required String userId,
    required String title,
    required String description,
    required String category,
    required List<XFile>? files,
    required MaintenanceReportType type,
    required String? compoundId,
  });
}
