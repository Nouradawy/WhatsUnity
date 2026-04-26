import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// Opens a browser-backed database in IndexedDB for Flutter Web/PWA.
Future<Database> openPlatformDatabase({
  required String path,
  required int version,
  required Future<void> Function(Database db, int version) onCreate,
  required Future<void> Function(Database db, int oldVersion, int newVersion)
      onUpgrade,
}) async {
  final options = OpenDatabaseOptions(
    version: version,
    onCreate: onCreate,
    onUpgrade: onUpgrade,
  );

  try {
    return await databaseFactoryFfiWeb.openDatabase(path, options: options);
  } catch (_) {
    // Fallback for environments where shared workers are unavailable or when
    // `sqflite_sw.js` is not present. Keeps chat functional on web.
    return databaseFactoryFfiWebNoWebWorker.openDatabase(
      path,
      options: options,
    );
  }
}
