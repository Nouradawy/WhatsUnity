import '../../../../core/models/MaintenanceReport.dart';

abstract class MaintenanceState {}

class MaintenanceInitial extends MaintenanceState {}

class MaintenanceLoading extends MaintenanceState {}

class MaintenanceLoaded extends MaintenanceState {
  final List<MaintenanceReports> reports;
  final List<MaintenanceReportsAttachments> attachments;
  MaintenanceLoaded({required this.reports, required this.attachments});
}

class MaintenanceSubmitting extends MaintenanceState {}

class MaintenanceSubmitSuccess extends MaintenanceState {}

class MaintenanceError extends MaintenanceState {
  final String message;
  MaintenanceError({required this.message});
}

class MaintenanceExpandToggled extends MaintenanceState {
  final bool isExpanded;
  final int index;
  MaintenanceExpandToggled({required this.isExpanded, required this.index});
}

class MaintenanceNotesLoaded extends MaintenanceState {
  final List<MaintenanceReportsHistory> notes;
  MaintenanceNotesLoaded({required this.notes});
}

class MaintenanceNotePosted extends MaintenanceState {}

class MaintenanceStatusUpdated extends MaintenanceState {}
