import 'package:sqflite_common/sqlite_api.dart';

import 'database_open_delegate_io.dart'
    if (dart.library.js_interop) 'database_open_delegate_web.dart'
    as delegate;

/// Opens the local database with the platform-specific factory.
Future<Database> openPlatformDatabase({
  required String path,
  required int version,
  required Future<void> Function(Database db, int version) onCreate,
  required Future<void> Function(Database db, int oldVersion, int newVersion)
      onUpgrade,
}) {
  return delegate.openPlatformDatabase(
    path: path,
    version: version,
    onCreate: onCreate,
    onUpgrade: onUpgrade,
  );
}
