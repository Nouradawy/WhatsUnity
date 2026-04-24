import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/config/Enums.dart';
import '../../../../core/models/MaintenanceReport.dart';
import 'manager_state.dart';

class ManagerCubit extends Cubit<ManagerCubitStates>{
  ManagerCubit():super(ManagerInitialState());
  
  static ManagerCubit get(context) => BlocProvider.of(context);

  int filterIndex = 0;
  MaintenanceReportType currentMaintenanceType = MaintenanceReportType.maintenance;
  List<MaintenanceReports> maintenanceDataFiltered = [];
  bool isAnnouncment = false;

  void resetToInitial() {
    emit(ManagerInitialState());
  }

  void loadAnnouncement(){
    isAnnouncment = true;
    emit(LoadAnnouncementState());
  }

  void filterRequests ({
    required List<MaintenanceReports> reports,
    required MaintenanceReportType type,
    ManagerReportsFilter? statusFilter}) {
    isAnnouncment = false;
    if(statusFilter == ManagerReportsFilter.all) {
      maintenanceDataFiltered = reports;
    } else {
      maintenanceDataFiltered = reports.where((main) => 
        main.type == type && managerReportsFilterString(main.states) == statusFilter
      ).toList();
    }
    emit(FilterDataState());
  }
}
