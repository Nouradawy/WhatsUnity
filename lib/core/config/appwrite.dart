import 'package:appwrite/appwrite.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

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

/// The Appwrite database that holds all collections (profiles, user_roles, …).
/// Read from APPWRITE_DATABASE_ID in .env.
late final String appwriteDatabaseId;

Future<void> initAppwrite() async {
  final endpoint = dotenv.env['APPWRITE_ENDPOINT'] ?? 'https://cloud.appwrite.io/v1';
  final projectId = dotenv.env['APPWRITE_PROJECT_ID']!;
  appwriteDatabaseId = dotenv.env['APPWRITE_DATABASE_ID']!;

  appwriteClient = Client()
      .setEndpoint(endpoint)
      .setProject(projectId);

  appwriteAccount = Account(appwriteClient);
  appwriteDatabases = Databases(appwriteClient);
  appwriteTables = TablesDB(appwriteClient);
  appwriteRealtime = Realtime(appwriteClient);
}
