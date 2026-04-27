import 'package:WhatsUnity/core/config/appwrite.dart';
import 'package:WhatsUnity/core/media/media_services.dart';
import 'package:WhatsUnity/core/services/database_helper.dart';
import 'package:WhatsUnity/core/services/message_notification_lifecycle_service.dart';
import 'package:WhatsUnity/core/services/push_target_registration_service.dart';
import 'package:WhatsUnity/core/sync/sync_engine.dart';
import 'package:WhatsUnity/core/sync/sync_job_local_data_source.dart';
import 'package:WhatsUnity/features/admin/data/datasources/admin_remote_data_source.dart';
import 'package:WhatsUnity/features/admin/data/repositories/admin_repository_impl.dart';
import 'package:WhatsUnity/features/admin/domain/repositories/admin_repository.dart';
import 'package:WhatsUnity/features/chat/data/datasources/chat_local_data_source.dart';
import 'package:WhatsUnity/features/chat/data/datasources/chat_remote_data_source.dart';
import 'package:WhatsUnity/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:WhatsUnity/features/chat/data/repositories/chat_sync_repository_impl.dart';
import 'package:WhatsUnity/features/chat/domain/repositories/chat_repository.dart';
import 'package:WhatsUnity/features/chat/domain/repositories/chat_sync_repository.dart';
import 'package:WhatsUnity/features/maintenance/data/datasources/maintenance_local_data_source.dart';
import 'package:WhatsUnity/features/maintenance/data/datasources/maintenance_remote_data_source.dart';
import 'package:WhatsUnity/features/maintenance/data/repositories/maintenance_sync_repository_impl.dart';
import 'package:WhatsUnity/features/maintenance/domain/repositories/maintenance_sync_repository.dart';

/// App-level dependency container used to keep `main.dart` lightweight
/// and avoid a deep provider tree at the app root.
class AppServices {
  static late final ChatLocalDataSource chatLocalDataSource;
  static late final SyncJobLocalDataSource syncJobLocalDataSource;
  static late final MaintenanceLocalDataSource maintenanceLocalDataSource;
  static late final ChatRemoteDataSource chatRemoteDataSource;
  static late final MaintenanceRemoteDataSource maintenanceRemoteDataSource;
  static late final SyncEngine syncEngine;
  static late final ChatSyncRepository chatSyncRepository;
  static late final MaintenanceSyncRepository maintenanceSyncRepository;
  static late final AdminRepository adminRepository;
  static late final ChatRepository chatRepository;
  static late final MessageNotificationLifecycleService
      messageNotificationLifecycleService;
  static late final PushTargetRegistrationService pushTargetRegistrationService;

  static void initialize() {
    chatLocalDataSource = ChatLocalDataSourceImpl(DatabaseHelper.instance);
    syncJobLocalDataSource = SyncJobLocalDataSourceImpl(DatabaseHelper.instance);
    maintenanceLocalDataSource = MaintenanceLocalDataSourceImpl(
      DatabaseHelper.instance,
    );

    chatRemoteDataSource = ChatRemoteDataSourceImpl(
      databases: appwriteTables,
      realtime: appwriteRealtime,
    );
    maintenanceRemoteDataSource = AppwriteMaintenanceRemoteDataSourceImpl(
      databases: appwriteTables,
    );

    syncEngine = SyncEngine(
      jobStore: syncJobLocalDataSource,
      remote: chatRemoteDataSource,
      local: chatLocalDataSource,
      maintenanceRemote: maintenanceRemoteDataSource,
      maintenanceLocal: maintenanceLocalDataSource,
      mediaUpload: mediaUploadService,
    )..start();

    chatSyncRepository = ChatSyncRepositoryImpl(
      local: chatLocalDataSource,
      jobStore: syncJobLocalDataSource,
      engine: syncEngine,
    );
    maintenanceSyncRepository = MaintenanceSyncRepositoryImpl(
      local: maintenanceLocalDataSource,
      jobStore: syncJobLocalDataSource,
      engine: syncEngine,
    );
    adminRepository = AdminRepositoryImpl(
      remoteDataSource: AppwriteAdminRemoteDataSourceImpl(
        databases: appwriteTables,
      ),
    );
    chatRepository = ChatRepositoryImpl(
      remoteDataSource: chatRemoteDataSource,
      localDataSource: chatLocalDataSource,
    );
    messageNotificationLifecycleService = MessageNotificationLifecycleService();
    pushTargetRegistrationService = PushTargetRegistrationService();
  }
}

