import 'package:appwrite/appwrite.dart';

import 'runtime_env.dart';

/// Appwrite client singletons — initialised in [main] before [runApp].
///
/// Usage elsewhere in the app:
///   import 'package:WhatsUnity/core/config/appwrite.dart';
///   // [appwriteAccount], [appwriteClient], [appwriteDatabaseId],
///   // [appwriteDatabases], [appwriteRealtime]
late final Client appwriteClient;
late final Account appwriteAccount;

/// Databases service for [appwriteDatabaseId] (legacy; prefer [appwriteTables] for new code).
late final Databases appwriteDatabases;

/// TablesDB — non-deprecated row APIs (`listRows`, `createRow`, …). Replaces [Databases] for new usage.
late final TablesDB appwriteTables;

/// Realtime WebSocket for database document subscriptions (e.g. chat [messages]).
late final Realtime appwriteRealtime;

/// HTTP executions for Appwrite Functions (e.g. R2 presign, Gumlet asset create).
late final Functions appwriteFunctions;

/// The Appwrite database that holds all collections (profiles, user_roles, …).
/// Read from compile-time `APPWRITE_DATABASE_ID` (see [RuntimeEnv]).
late final String appwriteDatabaseId;

Future<void> initAppwrite() async {
  final endpoint =
      RuntimeEnv.appwriteEndpoint ?? 'https://cloud.appwrite.io/v1';
  final projectId = RuntimeEnv.appwriteProjectId;
  appwriteDatabaseId = RuntimeEnv.appwriteDatabaseId;

  appwriteClient = Client()
      .setEndpoint(endpoint)
      .setProject(projectId);

  appwriteAccount = Account(appwriteClient);
  appwriteDatabases = Databases(appwriteClient);
  appwriteTables = TablesDB(appwriteClient);
  appwriteRealtime = Realtime(appwriteClient);
  appwriteFunctions = Functions(appwriteClient);
}
