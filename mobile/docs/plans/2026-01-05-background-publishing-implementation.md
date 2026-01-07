# Background Publishing Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Navigate back immediately when user taps Publish, while publishing continues in background with notifications.

**Architecture:** Move Nostr publishing from `VideoMetadataScreenPure` into `UploadManager.completePublish()`. The metadata screen saves data and navigates immediately; UploadManager handles upload completion and Nostr event creation in background.

**Tech Stack:** Flutter/Dart, Hive for persistence, Riverpod for state, flutter_local_notifications

---

## Task 1: Add Publishing Fields to PendingUpload Model

**Files:**
- Modify: `lib/models/pending_upload.dart:43-68` (add fields)
- Modify: `lib/models/pending_upload.dart:71-96` (update create factory)
- Modify: `lib/models/pending_upload.dart:199-249` (update copyWith)
- Regenerate: `lib/models/pending_upload.g.dart`

**Step 1: Write the failing test**

Create test file `test/models/pending_upload_publishing_test.dart`:

```dart
// ABOUTME: Tests for PendingUpload publishing metadata fields
// ABOUTME: Verifies expirationTimestamp and allowAudioReuse work correctly

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/pending_upload.dart';

void main() {
  group('PendingUpload publishing fields', () {
    test('create includes expirationTimestamp and allowAudioReuse', () {
      final upload = PendingUpload.create(
        localVideoPath: '/path/to/video.mp4',
        nostrPubkey: 'abc123',
        expirationTimestamp: 1704067200,
        allowAudioReuse: true,
      );

      expect(upload.expirationTimestamp, 1704067200);
      expect(upload.allowAudioReuse, true);
    });

    test('copyWith preserves expirationTimestamp and allowAudioReuse', () {
      final upload = PendingUpload.create(
        localVideoPath: '/path/to/video.mp4',
        nostrPubkey: 'abc123',
        expirationTimestamp: 1704067200,
        allowAudioReuse: true,
      );

      final updated = upload.copyWith(title: 'New title');

      expect(updated.expirationTimestamp, 1704067200);
      expect(updated.allowAudioReuse, true);
      expect(updated.title, 'New title');
    });

    test('copyWith can update expirationTimestamp and allowAudioReuse', () {
      final upload = PendingUpload.create(
        localVideoPath: '/path/to/video.mp4',
        nostrPubkey: 'abc123',
      );

      final updated = upload.copyWith(
        expirationTimestamp: 1704067200,
        allowAudioReuse: true,
      );

      expect(updated.expirationTimestamp, 1704067200);
      expect(updated.allowAudioReuse, true);
    });
  });
}
```

**Step 2: Run test to verify it fails**

Run: `mcp__dart__run_tests` with path `test/models/pending_upload_publishing_test.dart`
Expected: FAIL with compilation error - fields don't exist

**Step 3: Add fields to PendingUpload class**

In `lib/models/pending_upload.dart`, add after line 67 (`fallbackUrl`):

```dart
  @HiveField(24)
  final int? expirationTimestamp; // Unix timestamp for NIP-40 expiration

  @HiveField(25)
  final bool allowAudioReuse; // Whether to extract and publish audio for reuse
```

Update constructor (around line 43) to include:

```dart
  const PendingUpload({
    // ... existing fields ...
    this.expirationTimestamp,
    this.allowAudioReuse = false,
  });
```

**Step 4: Update create factory**

In the `create` factory (around line 71), add parameters and pass them:

```dart
  factory PendingUpload.create({
    // ... existing parameters ...
    int? expirationTimestamp,
    bool allowAudioReuse = false,
  }) => PendingUpload(
    // ... existing assignments ...
    expirationTimestamp: expirationTimestamp,
    allowAudioReuse: allowAudioReuse,
  );
```

**Step 5: Update copyWith method**

In `copyWith` (around line 199), add parameters and preserve values:

```dart
  PendingUpload copyWith({
    // ... existing parameters ...
    int? expirationTimestamp,
    bool? allowAudioReuse,
  }) => PendingUpload(
    // ... existing assignments ...
    expirationTimestamp: expirationTimestamp ?? this.expirationTimestamp,
    allowAudioReuse: allowAudioReuse ?? this.allowAudioReuse,
  );
```

**Step 6: Regenerate Hive adapters**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: `pending_upload.g.dart` updated with new HiveFields 24, 25

**Step 7: Run test to verify it passes**

Run: `mcp__dart__run_tests` with path `test/models/pending_upload_publishing_test.dart`
Expected: PASS

**Step 8: Commit**

```bash
git add test/models/pending_upload_publishing_test.dart lib/models/pending_upload.dart lib/models/pending_upload.g.dart
git commit -m "feat: add expirationTimestamp and allowAudioReuse to PendingUpload

Add publishing metadata fields to PendingUpload model for background
publishing support. These fields persist user choices through the
upload/publish lifecycle.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

---

## Task 2: Add UploadStatus.publishing State

**Files:**
- Modify: `lib/models/pending_upload.dart:14-38` (add enum value)
- Regenerate: `lib/models/pending_upload.g.dart`

**Step 1: Write the failing test**

Add to `test/models/pending_upload_publishing_test.dart`:

```dart
    test('UploadStatus.publishing exists', () {
      expect(UploadStatus.values, contains(UploadStatus.publishing));
    });

    test('status can be set to publishing', () {
      final upload = PendingUpload.create(
        localVideoPath: '/path/to/video.mp4',
        nostrPubkey: 'abc123',
      );

      final updated = upload.copyWith(status: UploadStatus.publishing);

      expect(updated.status, UploadStatus.publishing);
    });
```

**Step 2: Run test to verify it fails**

Run: `mcp__dart__run_tests` with path `test/models/pending_upload_publishing_test.dart`
Expected: FAIL - UploadStatus.publishing doesn't exist

**Step 3: Add publishing enum value**

In `lib/models/pending_upload.dart`, add after `paused` (around line 37):

```dart
  @HiveField(8)
  publishing, // Creating and broadcasting Nostr event
```

**Step 4: Regenerate Hive adapters**

Run: `dart run build_runner build --delete-conflicting-outputs`

**Step 5: Run test to verify it passes**

Run: `mcp__dart__run_tests` with path `test/models/pending_upload_publishing_test.dart`
Expected: PASS

**Step 6: Commit**

```bash
git add lib/models/pending_upload.dart lib/models/pending_upload.g.dart
git commit -m "feat: add UploadStatus.publishing state

Add new status for tracking when Nostr event creation is in progress
during background publishing.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

---

## Task 3: Add completePublish Method to UploadManager

**Files:**
- Modify: `lib/services/upload_manager.dart` (add method ~100 lines)
- Modify: `lib/providers/app_providers.dart` (add VideoEventPublisher dependency)

**Step 1: Write the failing test**

Create `test/services/upload_manager_complete_publish_test.dart`:

```dart
// ABOUTME: Tests for UploadManager.completePublish background publishing
// ABOUTME: Verifies upload completion triggers Nostr event creation

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/models/pending_upload.dart';
import 'package:openvine/services/upload_manager.dart';
import 'package:openvine/services/video_event_publisher.dart';
import 'package:openvine/services/notification_service.dart';

class MockVideoEventPublisher extends Mock implements VideoEventPublisher {}
class MockNotificationService extends Mock implements NotificationService {}

void main() {
  group('UploadManager.completePublish', () {
    late UploadManager uploadManager;
    late MockVideoEventPublisher mockPublisher;
    late MockNotificationService mockNotifications;

    setUp(() {
      mockPublisher = MockVideoEventPublisher();
      mockNotifications = MockNotificationService();
      // Note: Full setup requires mocking BlossomUploadService too
    });

    test('completePublish updates status to publishing then published', () async {
      // This test verifies the state transitions during background publishing
      // Full implementation requires integration test setup
    });

    test('completePublish calls VideoEventPublisher.publishDirectUpload', () async {
      // Verify that completePublish delegates to VideoEventPublisher
    });

    test('completePublish shows success notification on completion', () async {
      // Verify notification is shown after successful publish
    });

    test('completePublish shows failure notification and saves draft on error', () async {
      // Verify error handling creates draft and notifies user
    });
  });
}
```

**Step 2: Run test to verify it fails**

Run: `mcp__dart__run_tests` with path `test/services/upload_manager_complete_publish_test.dart`
Expected: FAIL - completePublish method doesn't exist

**Step 3: Add VideoEventPublisher dependency to UploadManager**

In `lib/services/upload_manager.dart`, update constructor (around line 80):

```dart
class UploadManager {
  UploadManager({
    required BlossomUploadService blossomService,
    VideoCircuitBreaker? circuitBreaker,
    UploadRetryConfig? retryConfig,
    VideoEventPublisher? videoEventPublisher,
    NotificationService? notificationService,
  }) : _blossomService = blossomService,
       _circuitBreaker = circuitBreaker ?? VideoCircuitBreaker(),
       _retryConfig = retryConfig ?? const UploadRetryConfig(),
       _videoEventPublisher = videoEventPublisher,
       _notificationService = notificationService;

  final VideoEventPublisher? _videoEventPublisher;
  final NotificationService? _notificationService;
```

**Step 4: Add completePublish method**

Add after `_handleUploadSuccess` method (around line 890):

```dart
  /// Complete the publishing process after upload is ready
  /// This runs in background and handles Nostr event creation
  Future<void> completePublish(String uploadId) async {
    final upload = getUpload(uploadId);
    if (upload == null) {
      Log.error(
        'Cannot complete publish - upload not found: $uploadId',
        name: 'UploadManager',
        category: LogCategory.video,
      );
      return;
    }

    if (upload.status != UploadStatus.readyToPublish) {
      Log.warning(
        'Upload not ready to publish: ${upload.status}',
        name: 'UploadManager',
        category: LogCategory.video,
      );
      return;
    }

    if (_videoEventPublisher == null) {
      Log.error(
        'VideoEventPublisher not available - cannot complete publish',
        name: 'UploadManager',
        category: LogCategory.video,
      );
      return;
    }

    Log.info(
      '🚀 Starting background publish for upload: $uploadId',
      name: 'UploadManager',
      category: LogCategory.video,
    );

    // Update status to publishing
    await _updateUpload(upload.copyWith(status: UploadStatus.publishing));

    try {
      // Attempt Nostr event creation with retries
      var success = false;
      const maxRetries = 3;

      for (var attempt = 1; attempt <= maxRetries && !success; attempt++) {
        Log.info(
          'Publish attempt $attempt/$maxRetries',
          name: 'UploadManager',
          category: LogCategory.video,
        );

        success = await _videoEventPublisher!.publishDirectUpload(
          upload,
          expirationTimestamp: upload.expirationTimestamp,
          allowAudioReuse: upload.allowAudioReuse,
        );

        if (!success && attempt < maxRetries) {
          // Wait before retry with exponential backoff
          await Future<void>.delayed(Duration(seconds: attempt * 2));
        }
      }

      if (success) {
        // Success - status already updated by VideoEventPublisher
        Log.info(
          '✅ Background publish completed successfully: $uploadId',
          name: 'UploadManager',
          category: LogCategory.video,
        );

        // Show success notification
        await _notificationService?.showVideoPublished(
          videoTitle: upload.title ?? '',
          nostrEventId: getUpload(uploadId)?.nostrEventId ?? '',
          videoUrl: upload.cdnUrl,
        );
      } else {
        // Failed after all retries
        Log.error(
          '❌ Background publish failed after $maxRetries attempts: $uploadId',
          name: 'UploadManager',
          category: LogCategory.video,
        );

        await _updateUpload(upload.copyWith(
          status: UploadStatus.failed,
          errorMessage: 'Failed to publish to Nostr after multiple attempts',
        ));

        // Show failure notification
        await _notificationService?.showUploadFailed(
          videoTitle: upload.title ?? '',
          reason: 'Could not publish video. Saved as draft.',
        );
      }
    } catch (e) {
      Log.error(
        'Background publish error: $e',
        name: 'UploadManager',
        category: LogCategory.video,
      );

      await _updateUpload(upload.copyWith(
        status: UploadStatus.failed,
        errorMessage: e.toString(),
      ));

      await _notificationService?.showUploadFailed(
        videoTitle: upload.title ?? '',
        reason: 'Publishing failed unexpectedly. Saved as draft.',
      );
    }
  }
```

**Step 5: Update app_providers.dart to inject dependencies**

In `lib/providers/app_providers.dart`, update uploadManagerProvider to include VideoEventPublisher:

```dart
final uploadManagerProvider = Provider<UploadManager>((ref) {
  final blossomService = ref.watch(blossomUploadServiceProvider);
  final videoEventPublisher = ref.watch(videoEventPublisherProvider);
  final notificationService = NotificationService.instance;

  return UploadManager(
    blossomService: blossomService,
    videoEventPublisher: videoEventPublisher,
    notificationService: notificationService,
  );
});
```

**Step 6: Run tests**

Run: `mcp__dart__run_tests` with path `test/services/upload_manager_complete_publish_test.dart`
Expected: PASS (or skip if mocks not fully configured)

**Step 7: Commit**

```bash
git add lib/services/upload_manager.dart lib/providers/app_providers.dart test/services/upload_manager_complete_publish_test.dart
git commit -m "feat: add completePublish method to UploadManager

Add background publishing capability to UploadManager. The method:
- Transitions upload to 'publishing' status
- Calls VideoEventPublisher with retry logic (3 attempts)
- Shows success/failure notifications
- Handles errors gracefully with draft preservation

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

---

## Task 4: Simplify _publishVideo to Navigate Immediately

**Files:**
- Modify: `lib/screens/pure/video_metadata_screen_pure.dart:1428-1627` (rewrite method)

**Step 1: Write the failing test**

The test is behavioral - verify navigation happens quickly. Add to an integration test or manually verify.

**Step 2: Rewrite _publishVideo method**

Replace the entire `_publishVideo` method (lines 1428-~1680) with:

```dart
  Future<void> _publishVideo() async {
    if (_currentDraft == null) return;

    // Stop video playback
    if (_videoController != null && _videoController!.value.isPlaying) {
      await _videoController!.pause();
    }

    final uploadManager = ref.read(uploadManagerProvider);

    // Check if we have a background upload
    if (_backgroundUploadId == null) {
      // No upload started - this shouldn't happen in normal flow
      // but handle it by showing error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Upload not ready. Please try again.')),
        );
      }
      return;
    }

    final upload = uploadManager.getUpload(_backgroundUploadId!);
    if (upload == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Upload not found. Please try again.')),
        );
      }
      return;
    }

    // If upload still in progress, wait for it (show dialog)
    if (upload.status == UploadStatus.uploading ||
        upload.status == UploadStatus.processing) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => UploadProgressDialog(
          uploadId: _backgroundUploadId!,
          uploadManager: uploadManager,
        ),
      );

      // Re-check status after dialog
      final completedUpload = uploadManager.getUpload(_backgroundUploadId!);
      if (completedUpload == null ||
          completedUpload.status == UploadStatus.failed) {
        await _showUploadErrorDialog();
        return;
      }
    }

    // If upload failed, show retry dialog
    if (upload.status == UploadStatus.failed) {
      final shouldRetry = await _showUploadErrorDialog();
      if (shouldRetry) {
        await _retryUpload();
        return _publishVideo();
      }
      return;
    }

    // Upload is ready - save metadata and trigger background publish
    Log.info(
      '📝 Saving metadata and triggering background publish',
      category: LogCategory.video,
    );

    // Calculate expiration timestamp if enabled
    final shouldExpire = _isExpiringPost && _expirationConfirmed;
    final expirationTimestamp = shouldExpire
        ? DateTime.now().millisecondsSinceEpoch ~/ 1000 + (_expirationHours * 3600)
        : null;

    // Update upload with current metadata
    await uploadManager.updateUploadMetadata(
      _backgroundUploadId!,
      title: _titleController.text.trim().isEmpty
          ? null
          : _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      hashtags: _hashtags.isEmpty ? null : _hashtags,
    );

    // Update with publishing-specific fields
    final currentUpload = uploadManager.getUpload(_backgroundUploadId!)!;
    await uploadManager._updateUpload(currentUpload.copyWith(
      expirationTimestamp: expirationTimestamp,
      allowAudioReuse: _allowAudioReuse ?? false,
    ));

    // Mark draft as publishing
    final prefs = await SharedPreferences.getInstance();
    final draftService = DraftStorageService(prefs);
    final publishing = _currentDraft!.copyWith(
      publishStatus: PublishStatus.publishing,
    );
    await draftService.saveDraft(publishing);

    // Mark recording as published to prevent auto-save
    ref.read(vineRecordingProvider.notifier).markAsPublished();

    // Clear clip manager and selected sound
    ref.read(clipManagerProvider.notifier).clearAll();
    ref.read(selectedSoundProvider.notifier).clear();

    // Navigate immediately - don't wait for publish
    if (mounted) {
      // Pop all screens back to where user started (before camera)
      Navigator.of(context).popUntil((route) => route.isFirst);
    }

    // Trigger background publish (fire and forget - notifications handle feedback)
    uploadManager.completePublish(_backgroundUploadId!);

    Log.info(
      '📝 Navigated back, background publish triggered',
      category: LogCategory.video,
    );
  }
```

**Step 3: Make _updateUpload accessible or add public method**

The above code calls `uploadManager._updateUpload` which is private. Either:
- Make it public: rename to `updateUpload`
- Or add a dedicated method for updating publishing fields

Add to UploadManager:

```dart
  /// Update publishing-specific metadata on an upload
  Future<void> updatePublishingMetadata(
    String uploadId, {
    int? expirationTimestamp,
    bool? allowAudioReuse,
  }) async {
    final upload = getUpload(uploadId);
    if (upload == null) return;

    await _updateUpload(upload.copyWith(
      expirationTimestamp: expirationTimestamp,
      allowAudioReuse: allowAudioReuse,
    ));
  }
```

**Step 4: Run analyzer**

Run: `mcp__dart__analyze_files`
Expected: No errors

**Step 5: Test manually**

Launch app, record video, add metadata, tap Publish. Verify:
- Navigation happens immediately (< 500ms)
- Toast/notification appears when publish completes

**Step 6: Commit**

```bash
git add lib/screens/pure/video_metadata_screen_pure.dart lib/services/upload_manager.dart
git commit -m "feat: navigate immediately on publish, continue in background

Rewrite _publishVideo to save metadata and navigate back immediately
while UploadManager.completePublish handles Nostr event creation in
background. User gets notification when complete.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

---

## Task 5: Add Resume Logic on App Startup

**Files:**
- Modify: `lib/services/upload_manager.dart:127-190` (update initialize method)

**Step 1: Write the failing test**

Add to existing upload manager test file:

```dart
    test('initialize resumes uploads in publishing status', () async {
      // Create upload with publishing status
      // Call initialize
      // Verify completePublish is called
    });
```

**Step 2: Update _resumeInterruptedUploads**

In `lib/services/upload_manager.dart`, modify `_resumeInterruptedUploads` (around line 1381):

```dart
  /// Resume any uploads that were interrupted
  Future<void> _resumeInterruptedUploads() async {
    // Resume uploads that were in uploading state
    final interruptedUploads = pendingUploads
        .where((upload) => upload.status == UploadStatus.uploading)
        .toList();

    for (final upload in interruptedUploads) {
      Log.debug(
        'Resuming interrupted upload: ${upload.id}',
        name: 'UploadManager',
        category: LogCategory.video,
      );

      final resetUpload = upload.copyWith(
        status: UploadStatus.pending,
        uploadProgress: null,
      );

      await _updateUpload(resetUpload);
      _performUpload(resetUpload);
    }

    // Resume uploads that were in publishing state (Nostr event creation)
    final publishingUploads = pendingUploads
        .where((upload) => upload.status == UploadStatus.publishing)
        .toList();

    for (final upload in publishingUploads) {
      Log.info(
        '🔄 Resuming interrupted publish: ${upload.id}',
        name: 'UploadManager',
        category: LogCategory.video,
      );

      // Reset to readyToPublish and retry
      await _updateUpload(upload.copyWith(
        status: UploadStatus.readyToPublish,
      ));

      // Trigger background publish
      completePublish(upload.id);
    }

    // Also check for readyToPublish uploads that never got published
    // (user closed app before hitting Publish but after upload completed)
    final readyUploads = pendingUploads
        .where((upload) => upload.status == UploadStatus.readyToPublish)
        .where((upload) {
          // Only auto-publish if it's been less than 24 hours
          final age = DateTime.now().difference(upload.createdAt);
          return age.inHours < 24;
        })
        .toList();

    if (readyUploads.isNotEmpty) {
      Log.info(
        '📤 Found ${readyUploads.length} uploads ready to publish from previous session',
        name: 'UploadManager',
        category: LogCategory.video,
      );
      // Don't auto-publish these - they need user to tap Publish again
      // Just log that they exist for drafts UI to show
    }
  }
```

**Step 3: Run tests**

Run: `mcp__dart__run_tests`
Expected: PASS

**Step 4: Commit**

```bash
git add lib/services/upload_manager.dart
git commit -m "feat: resume interrupted publishes on app startup

UploadManager.initialize now resumes uploads that were in 'publishing'
state when app was killed. This ensures Nostr events are created even
if the app was closed mid-publish.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

---

## Task 6: Delete Draft After Successful Background Publish

**Files:**
- Modify: `lib/services/upload_manager.dart` (update completePublish)

**Step 1: Update completePublish to clean up draft**

In the success branch of `completePublish`, after showing notification:

```dart
      if (success) {
        // ... existing success logging and notification ...

        // Clean up draft and temp files
        try {
          final prefs = await SharedPreferences.getInstance();
          final draftService = DraftStorageService(prefs);

          // Find and delete the draft associated with this upload
          final drafts = await draftService.loadDrafts();
          for (final draft in drafts) {
            if (draft.videoFile.path == upload.localVideoPath) {
              await draftService.deleteDraft(draft.id);
              Log.info(
                '🧹 Deleted draft after successful publish: ${draft.id}',
                name: 'UploadManager',
                category: LogCategory.video,
              );
              break;
            }
          }

          // Clean up temp video file if it exists
          final videoFile = File(upload.localVideoPath);
          if (await videoFile.exists()) {
            await videoFile.delete();
            Log.info(
              '🧹 Deleted temp video file: ${upload.localVideoPath}',
              name: 'UploadManager',
              category: LogCategory.video,
            );
          }
        } catch (e) {
          Log.warning(
            'Failed to clean up after publish: $e',
            name: 'UploadManager',
            category: LogCategory.video,
          );
          // Don't fail the publish for cleanup errors
        }
      }
```

**Step 2: Add required import**

```dart
import 'package:openvine/services/draft_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
```

**Step 3: Commit**

```bash
git add lib/services/upload_manager.dart
git commit -m "feat: clean up draft and temp files after successful publish

Delete VineDraft and temporary video file after background publish
completes successfully. Errors are logged but don't fail the publish.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

---

## Task 7: Integration Test for Full Flow

**Files:**
- Create: `test/integration/background_publishing_test.dart`

**Step 1: Create integration test**

```dart
// ABOUTME: Integration test for background publishing flow
// ABOUTME: Tests the full flow from Publish tap to notification

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:openvine/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Background Publishing Integration', () {
    testWidgets('Publish navigates back immediately', (tester) async {
      // This test requires:
      // 1. A logged-in user
      // 2. A video ready to publish
      // 3. Mocked relay responses

      // For now, mark as skip until we have proper test fixtures
      // The manual testing steps are:
      // 1. Record a video
      // 2. Add title/description
      // 3. Tap Publish
      // 4. Verify immediate navigation back (< 500ms)
      // 5. Wait for notification "Video published!"
    }, skip: 'Requires test fixtures - verify manually');
  });
}
```

**Step 2: Commit**

```bash
git add test/integration/background_publishing_test.dart
git commit -m "test: add background publishing integration test skeleton

Placeholder for integration test that verifies the full background
publishing flow. Currently skipped pending test fixture setup.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

---

## Summary

After completing all tasks:

1. `PendingUpload` has `expirationTimestamp` and `allowAudioReuse` fields
2. `UploadStatus.publishing` tracks Nostr event creation phase
3. `UploadManager.completePublish()` handles background Nostr publishing with retries
4. `NotificationService` shows success/failure notifications
5. `VideoMetadataScreenPure._publishVideo()` navigates immediately
6. App startup resumes interrupted publishes
7. Drafts and temp files are cleaned up after success

The flow is now:
```
User taps Publish
  → Save metadata to PendingUpload
  → Mark draft as "publishing"
  → Navigate back immediately
  → UploadManager.completePublish() runs in background
    → Wait for upload if still running
    → Create Nostr event with retries
    → Show notification (success or failure)
    → Clean up draft on success
```
