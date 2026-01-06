// ABOUTME: Provides singleton AppDatabase instance with proper lifecycle management
// ABOUTME: Database auto-closes when provider is disposed; auto-recreates on schema errors

import 'package:db_client/db_client.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'database_provider.g.dart';

/// Creates the database, handling schema mismatches by deleting and recreating.
Future<AppDatabase> _createDatabase() async {
  AppDatabase? db;
  try {
    db = AppDatabase();
    // Force database initialization to catch schema errors early
    await db.customSelect('SELECT 1').get();
    return db;
  } on SchemaMismatchException catch (e) {
    Log.warning(
      '[DB] $e - closing, deleting, and recreating database',
      name: 'DatabaseProvider',
      category: LogCategory.system,
    );
    // MUST close the database before deleting the file
    await db?.close();
    await deleteDatabaseFile();
    // Create fresh database - will trigger onCreate
    return AppDatabase();
  }
}

@Riverpod(keepAlive: true)
Future<AppDatabase> database(Ref ref) async {
  final db = await _createDatabase();
  ref.onDispose(() => db.close());
  return db;
}

/// AppDbClient wrapping the database for NostrClient integration.
/// Enables optimistic caching of Nostr events in the local database.
@Riverpod(keepAlive: true)
Future<AppDbClient> appDbClient(Ref ref) async {
  final db = await ref.watch(databaseProvider.future);
  final dbClient = DbClient(generatedDatabase: db);
  return AppDbClient(dbClient, db);
}
