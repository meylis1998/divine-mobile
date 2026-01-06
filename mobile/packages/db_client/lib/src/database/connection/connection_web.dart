// ABOUTME: Web-specific database connection using IndexedDB
// ABOUTME: Provides web-compatible storage through drift's web implementation

import 'package:drift/drift.dart';
// TODO(any): Migrate from deprecated drift/web.dart https://github.com/divinevideo/divine-mobile/issues/373
// ignore_for_file: deprecated_member_use
import 'package:drift/web.dart';

/// Open a database connection for web platform
/// Uses IndexedDB through drift's web implementation
QueryExecutor openConnection() {
  return LazyDatabase(() async {
    return WebDatabase(
      'local_relay_db',
    ); // Disabled - too verbose
  });
}

/// Get path to shared database file
/// On web, this returns a logical name for IndexedDB
Future<String> getSharedDatabasePath() async {
  return 'local_relay_db'; // IndexedDB database name
}

/// Delete the database on web platform.
///
/// Web uses IndexedDB which persists across sessions. This function is a
/// no-op on web since IndexedDB doesn't support simple file deletion.
/// The drift web implementation handles schema changes differently.
///
/// Returns false on web (no file to delete).
Future<bool> deleteDatabaseFile() async {
  // Web uses IndexedDB - more complex deletion not currently supported
  // For now, web doesn't support version-based DB reset
  return false;
}
