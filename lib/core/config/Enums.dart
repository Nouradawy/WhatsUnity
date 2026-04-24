enum UserState{
  New,
  underReview,
  approved,
  unApproved,
  onConflict,
  chatBanned,
  banned
}

enum AuthStatus { unknown, authenticated, unauthenticated }
enum Roles {user,manager,admin ,developer, owner, tenant}
enum OwnerTypes {owner,rental}
enum Storage {googleDrive,superbaseStorage,both}
enum MaintenanceCategory {plumbing,electricity,gardening , structural ,peast_control ,elevator , other}
enum SecurityCategory {disturbance ,sabotage, theft , other}
enum CareServiceCategory {building_cleaning,trash_pickup , other}
enum MaintenanceReportType{ maintenance,security, careService}
enum ProfileSection { account, preferences, support }
enum ReportAUserFilter{
  All,
  New,
  inReview,
  Resolved
}

enum ManagerReportsFilter{
  all,
  pending,
  inProgress,
  assigned,
  resolved,
  escalated,
  closed,

}

extension ManagerReportes on ManagerReportsFilter{
  String get value {
    switch (this) {
      case ManagerReportsFilter.all:
        return 'All';
      case ManagerReportsFilter.pending:
        return 'Pending';
      case ManagerReportsFilter.inProgress:
        return 'In Progress';
      case ManagerReportsFilter.assigned:
        return 'Assigned';
      case ManagerReportsFilter.resolved:
        return 'Resolved';
      case ManagerReportsFilter.escalated:
        return 'Escalated';
      case ManagerReportsFilter.closed:
        return 'Closed';
    }
  }
}

ManagerReportsFilter managerReportsFilterString (String value){
  return ManagerReportsFilter.values.firstWhere(
      (e) => e.value == value,
    orElse: ()=> ManagerReportsFilter.all,
  );
}

enum ReportAUserType{
  spam,
  harassment,
  selling,
  inappropriateContent
}