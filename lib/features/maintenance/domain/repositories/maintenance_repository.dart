import 'package:image_picker/image_picker.dart';
import '../../../../core/config/Enums.dart';
import '../../../../core/models/MaintenanceReport.dart';

abstract class MaintenanceRepository {
  Future<void> submitReport({
    required String title,
    required String description,
    required String category,
    required List<XFile>? files,
    required MaintenanceReportType type,
    required String? compoundId,
  });

  Future<List<MaintenanceReports>> getReports({
    required String compoundId,
    required MaintenanceReportType type,
  });

  Future<List<MaintenanceReportsAttachments>> getAttachments({
    required String compoundId,
    required MaintenanceReportType type,
  });

  Future<List<MaintenanceReportsHistory>> getReportNotes(String reportId);

  Future<void> postReportNote({
    required String reportId,
    required String actorId,
    required String action,
  });

  Future<void> updateReportStatus({
    required String reportId,
    required String status,
    required String compoundId,
    required MaintenanceReportType type,
  });
}
