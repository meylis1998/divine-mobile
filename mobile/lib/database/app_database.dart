// ABOUTME: Main Drift database that shares SQLite file with nostr_sdk
// ABOUTME: Provides reactive queries and unified event/profile caching

import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'tables.dart';
import 'daos/user_profiles_dao.dart';
import 'daos/nostr_events_dao.dart';
import 'daos/video_metrics_dao.dart';

part 'app_database.g.dart';

/// Main application database using Drift
///
/// This database shares the same SQLite file as nostr_sdk's embedded relay
/// (local_relay.db) to provide a single source of truth for all Nostr events.
///
/// Schema versioning:
/// - nostr_sdk: schema version 1-2 (event table)
/// - AppDatabase: schema version 3+ (adds user_profiles, etc.)
@DriftDatabase(tables: [NostrEvents, UserProfiles, VideoMetrics], daos: [UserProfilesDao, NostrEventsDao, VideoMetricsDao])
class AppDatabase extends _$AppDatabase {
  /// Default constructor - uses shared database path with nostr_sdk
  AppDatabase() : super(_openConnection());

  /// Test constructor - allows custom database path for testing
  AppDatabase.test(String path)
      : super(NativeDatabase(File(path), logStatements: false)); // Disabled - too verbose

  @override
  int get schemaVersion => 4;

  /// Open connection to shared database file
  static QueryExecutor _openConnection() {
    return LazyDatabase(() async {
      final dbPath = await _getSharedDatabasePath();
      return NativeDatabase(
        File(dbPath),
        logStatements: false, // Disabled - too verbose for production
      );
    });
  }

  /// Get path to shared database file
  ///
  /// Uses same pattern as nostr_sdk:
  /// {appDocuments}/openvine/database/local_relay.db
  static Future<String> _getSharedDatabasePath() async {
    final docDir = await getApplicationDocumentsDirectory();
    return p.join(docDir.path, 'openvine', 'database', 'local_relay.db');
  }

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          // In production, event table already exists from nostr_sdk
          // In tests, we need to create it ourselves
          await m.createTable(nostrEvents);
          await m.createTable(userProfiles);
          await m.createTable(videoMetrics);
        },
        onUpgrade: (m, from, to) async {
          // Migration from nostr_sdk schema v2 to AppDatabase schema v3
          if (from < 3) {
            // Add user_profiles table (event table already exists from nostr_sdk)
            await m.createTable(userProfiles);
          }

          // Migration from schema v3 to v4: Add video_metrics table
          if (from < 4) {
            await m.createTable(videoMetrics);

            // Create indices for common sort/filter operations
            await customStatement('''
              CREATE INDEX IF NOT EXISTS idx_video_metrics_loop_count
              ON video_metrics(loop_count DESC)
            ''');
            await customStatement('''
              CREATE INDEX IF NOT EXISTS idx_video_metrics_likes
              ON video_metrics(likes DESC)
            ''');
            await customStatement('''
              CREATE INDEX IF NOT EXISTS idx_video_metrics_views
              ON video_metrics(views DESC)
            ''');

            // Backfill metrics for ALL existing video events (kind 34236 and 6)
            // This parses tags from existing events and populates video_metrics
            // CRITICAL: Must happen during migration, not background, so queries work immediately
            await customStatement('''
              INSERT INTO video_metrics (event_id, loop_count, likes, views, comments, avg_completion,
                                         has_proofmode, has_device_attestation, has_pgp_signature, updated_at)
              SELECT
                e.id,
                CAST(json_extract(
                  (SELECT value FROM json_each(e.tags)
                   WHERE json_extract(value, '\$[0]') = 'loops' LIMIT 1),
                  '\$[1]'
                ) AS INTEGER),
                CAST(json_extract(
                  (SELECT value FROM json_each(e.tags)
                   WHERE json_extract(value, '\$[0]') = 'likes' LIMIT 1),
                  '\$[1]'
                ) AS INTEGER),
                NULL,
                CAST(json_extract(
                  (SELECT value FROM json_each(e.tags)
                   WHERE json_extract(value, '\$[0]') = 'comments' LIMIT 1),
                  '\$[1]'
                ) AS INTEGER),
                NULL,
                NULL,
                NULL,
                NULL,
                datetime('now')
              FROM event e
              WHERE e.kind IN (34236, 6)
            ''');
          }
        },
      );
}
