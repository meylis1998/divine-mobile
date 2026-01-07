// ABOUTME: Unit tests for VideoControllerPool service
// ABOUTME: Tests LRU eviction, capacity limits, and playing state protection

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/video_controller_pool.dart';

void main() {
  group('VideoControllerPool', () {
    late VideoControllerPool pool;

    setUp(() {
      pool = VideoControllerPool();
    });

    tearDown(() {
      pool.dispose();
    });

    group('slot management', () {
      test('requestSlot registers a new controller', () {
        expect(pool.activeCount, equals(0));

        final result = pool.requestSlot('video1');

        expect(result, isTrue);
        expect(pool.activeCount, equals(1));
        expect(pool.hasSlot('video1'), isTrue);
      });

      test('requestSlot returns false for already registered video', () {
        pool.requestSlot('video1');

        final result = pool.requestSlot('video1');

        expect(result, isFalse);
        expect(pool.activeCount, equals(1)); // Should not double-count
      });

      test('releaseSlot removes controller from pool', () {
        pool.requestSlot('video1');
        pool.requestSlot('video2');

        pool.releaseSlot('video1');

        expect(pool.activeCount, equals(1));
        expect(pool.hasSlot('video1'), isFalse);
        expect(pool.hasSlot('video2'), isTrue);
      });

      test('releaseSlot does nothing for unknown video', () {
        pool.requestSlot('video1');

        pool.releaseSlot('unknown');

        expect(pool.activeCount, equals(1));
      });
    });

    group('capacity limits', () {
      test('isAtLimit returns true when at max capacity', () {
        expect(pool.isAtLimit, isFalse);

        for (var i = 0; i < VideoControllerPool.maxConcurrentControllers; i++) {
          pool.requestSlot('video$i');
        }

        expect(pool.isAtLimit, isTrue);
        expect(pool.activeCount, equals(VideoControllerPool.maxConcurrentControllers));
      });

      test('availableSlots decreases as controllers are added', () {
        expect(pool.availableSlots, equals(VideoControllerPool.maxConcurrentControllers));

        pool.requestSlot('video1');
        expect(pool.availableSlots, equals(VideoControllerPool.maxConcurrentControllers - 1));

        pool.requestSlot('video2');
        expect(pool.availableSlots, equals(VideoControllerPool.maxConcurrentControllers - 2));
      });

      test('availableSlots increases when controllers are released', () {
        pool.requestSlot('video1');
        pool.requestSlot('video2');

        pool.releaseSlot('video1');

        expect(pool.availableSlots, equals(VideoControllerPool.maxConcurrentControllers - 1));
      });
    });

    group('LRU eviction', () {
      test('getEvictionCandidate returns oldest non-playing controller', () {
        pool.requestSlot('video1');
        pool.markInitialized('video1');
        pool.requestSlot('video2');
        pool.markInitialized('video2');
        pool.requestSlot('video3');
        pool.markInitialized('video3');

        final candidate = pool.getEvictionCandidate();

        expect(candidate, equals('video1')); // First added = oldest
      });

      test('getEvictionCandidate skips currently playing video', () {
        pool.requestSlot('video1');
        pool.markInitialized('video1');
        pool.requestSlot('video2');
        pool.markInitialized('video2');
        pool.requestSlot('video3');
        pool.markInitialized('video3');
        pool.markPlaying('video1'); // Mark oldest as playing

        final candidate = pool.getEvictionCandidate();

        expect(candidate, equals('video2')); // Skip video1, return next oldest
      });

      test('getEvictionCandidate skips initializing controllers', () {
        pool.requestSlot('video1'); // Marked as initializing
        pool.requestSlot('video2');
        pool.markInitialized('video2'); // Only video2 is done initializing

        final candidate = pool.getEvictionCandidate();

        expect(candidate, equals('video2')); // video1 is still initializing
      });

      test('getEvictionCandidate returns null when no candidates available', () {
        pool.requestSlot('video1');
        pool.markPlaying('video1');

        final candidate = pool.getEvictionCandidate();

        expect(candidate, isNull); // Only video is playing
      });

      test('recordAccess moves video to end of LRU list', () {
        pool.requestSlot('video1');
        pool.markInitialized('video1');
        pool.requestSlot('video2');
        pool.markInitialized('video2');
        pool.requestSlot('video3');
        pool.markInitialized('video3');

        // Access video1 to make it most recently used
        pool.recordAccess('video1');

        final candidate = pool.getEvictionCandidate();

        expect(candidate, equals('video2')); // video1 was accessed, so video2 is now oldest
      });

      test('getEvictionCandidates returns multiple candidates in LRU order', () {
        pool.requestSlot('video1');
        pool.markInitialized('video1');
        pool.requestSlot('video2');
        pool.markInitialized('video2');
        pool.requestSlot('video3');
        pool.markInitialized('video3');
        pool.requestSlot('video4');
        pool.markInitialized('video4');

        final candidates = pool.getEvictionCandidates(2);

        expect(candidates, equals(['video1', 'video2']));
      });

      test('getEvictionCandidates respects playing and initializing state', () {
        pool.requestSlot('video1');
        pool.markInitialized('video1');
        pool.markPlaying('video1'); // Playing
        pool.requestSlot('video2'); // Still initializing
        pool.requestSlot('video3');
        pool.markInitialized('video3');
        pool.requestSlot('video4');
        pool.markInitialized('video4');

        final candidates = pool.getEvictionCandidates(3);

        // video1 is playing, video2 is initializing - should get video3, video4
        expect(candidates, equals(['video3', 'video4']));
      });
    });

    group('playing state', () {
      test('markPlaying sets currentlyPlayingVideoId', () {
        pool.requestSlot('video1');
        pool.markPlaying('video1');

        expect(pool.currentlyPlayingVideoId, equals('video1'));
      });

      test('markNotPlaying clears currentlyPlayingVideoId', () {
        pool.requestSlot('video1');
        pool.markPlaying('video1');
        pool.markNotPlaying('video1');

        expect(pool.currentlyPlayingVideoId, isNull);
      });

      test('markNotPlaying only clears if matching video', () {
        pool.requestSlot('video1');
        pool.requestSlot('video2');
        pool.markPlaying('video1');
        pool.markNotPlaying('video2'); // Different video

        expect(pool.currentlyPlayingVideoId, equals('video1')); // Unchanged
      });

      test('releaseSlot clears playing state if released video was playing', () {
        pool.requestSlot('video1');
        pool.markPlaying('video1');

        pool.releaseSlot('video1');

        expect(pool.currentlyPlayingVideoId, isNull);
      });
    });

    group('initialization tracking', () {
      test('requestSlot marks video as initializing', () {
        pool.requestSlot('video1');

        expect(pool.isInitializing('video1'), isTrue);
      });

      test('markInitialized removes from initializing set', () {
        pool.requestSlot('video1');
        pool.markInitialized('video1');

        expect(pool.isInitializing('video1'), isFalse);
      });

      test('releaseSlot removes from initializing set', () {
        pool.requestSlot('video1');
        // Don't call markInitialized

        pool.releaseSlot('video1');

        expect(pool.isInitializing('video1'), isFalse);
      });
    });

    group('clear', () {
      test('clear removes all slots and resets state', () {
        pool.requestSlot('video1');
        pool.requestSlot('video2');
        pool.markPlaying('video1');

        pool.clear();

        expect(pool.activeCount, equals(0));
        expect(pool.currentlyPlayingVideoId, isNull);
        expect(pool.hasSlot('video1'), isFalse);
        expect(pool.hasSlot('video2'), isFalse);
      });
    });

    group('notifyListeners', () {
      test('notifies listeners on slot request', () {
        var notifyCount = 0;
        pool.addListener(() => notifyCount++);

        pool.requestSlot('video1');

        expect(notifyCount, equals(1));
      });

      test('notifies listeners on slot release', () {
        pool.requestSlot('video1');
        var notifyCount = 0;
        pool.addListener(() => notifyCount++);

        pool.releaseSlot('video1');

        expect(notifyCount, equals(1));
      });

      test('notifies listeners on markPlaying', () {
        pool.requestSlot('video1');
        var notifyCount = 0;
        pool.addListener(() => notifyCount++);

        pool.markPlaying('video1');

        expect(notifyCount, equals(1));
      });

      test('notifies listeners on markNotPlaying', () {
        pool.requestSlot('video1');
        pool.markPlaying('video1');
        var notifyCount = 0;
        pool.addListener(() => notifyCount++);

        pool.markNotPlaying('video1');

        expect(notifyCount, equals(1));
      });

      test('notifies listeners on clear', () {
        pool.requestSlot('video1');
        var notifyCount = 0;
        pool.addListener(() => notifyCount++);

        pool.clear();

        expect(notifyCount, equals(1));
      });
    });

    group('registeredVideoIds', () {
      test('returns list of all registered video IDs', () {
        pool.requestSlot('video1');
        pool.requestSlot('video2');
        pool.requestSlot('video3');

        final ids = pool.registeredVideoIds;

        expect(ids, containsAll(['video1', 'video2', 'video3']));
        expect(ids.length, equals(3));
      });
    });

    group('toString', () {
      test('includes relevant state information', () {
        pool.requestSlot('video1');
        pool.requestSlot('video2');
        pool.markInitialized('video1');
        pool.markPlaying('video1');

        final str = pool.toString();

        expect(str, contains('active: 2'));
        expect(str, contains('playing: video1'));
        expect(str, contains('initializing: 1'));
      });
    });
  });
}
