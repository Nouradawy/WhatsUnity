import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/config/Enums.dart';
import '../../../../core/models/MaintenanceReport.dart';
import '../../domain/repositories/maintenance_repository.dart';
import 'maintenance_state.dart';

class MaintenanceCubit extends Cubit<MaintenanceState> {
  final MaintenanceRepository repository;

  MaintenanceCubit({required this.repository}) : super(MaintenanceInitial());

  List<MaintenanceReports> reports = [];
  List<MaintenanceReportsAttachments> attachments = [];
  List<MaintenanceReportsHistory> reportNotes = [];
  bool isExpanded = false;
  int reportIndex = 0;

  Future<void> getMaintenanceReports({
    required String compoundId,
    required MaintenanceReportType type,
  }) async {
    emit(MaintenanceLoading());
    try {
      reports = await repository.getReports(compoundId: compoundId, type: type);
      attachments = await repository.getAttachments(compoundId: compoundId, type: type);
      emit(MaintenanceLoaded(reports: reports, attachments: attachments));
    } catch (e) {
      emit(MaintenanceError(message: e.toString()));
    }
  }

  Future<void> getReportNotes(String reportId) async {
    try {
      reportNotes = await repository.getReportNotes(reportId);
      emit(MaintenanceNotesLoaded(notes: reportNotes));
    } catch (e) {
      emit(MaintenanceError(message: e.toString()));
    }
  }

  Future<void> postReportNote({
    required String reportId,
    required String actorId,
    required String action,
  }) async {
    try {
      await repository.postReportNote(
        reportId: reportId,
        actorId: actorId,
        action: action,
      );
      emit(MaintenanceNotePosted());
      await getReportNotes(reportId);
    } catch (e) {
      emit(MaintenanceError(message: e.toString()));
    }
  }

  Future<void> updateReportStatus({
    required String reportId,
    required String status,
    required String compoundId,
    required MaintenanceReportType type,
  }) async {
    try {
      await repository.updateReportStatus(
        reportId: reportId,
        status: status,
        compoundId: compoundId,
        type: type,
      );
      emit(MaintenanceStatusUpdated());
      await getMaintenanceReports(compoundId: compoundId, type: type);
    } catch (e) {
      emit(MaintenanceError(message: e.toString()));
    }
  }

  Future<void> submitReport({
    required String title,
    required String description,
    required String category,
    required List<XFile>? files,
    required MaintenanceReportType type,
    required String? compoundId,
  }) async {
    emit(MaintenanceSubmitting());
    try {
      await repository.submitReport(
        title: title,
        description: description,
        category: category,
        files: files,
        type: type,
        compoundId: compoundId,
      );
      emit(MaintenanceSubmitSuccess());
      if (compoundId != null) {
        getMaintenanceReports(compoundId: compoundId, type: type);
      }
    } catch (e) {
      emit(MaintenanceError(message: e.toString()));
    }
  }

  void expandReport(int index) {
    if (reportIndex == index) {
      isExpanded = !isExpanded;
    } else {
      reportIndex = index;
      isExpanded = true;
    }
    emit(MaintenanceExpandToggled(isExpanded: isExpanded, index: reportIndex));
  }
}
