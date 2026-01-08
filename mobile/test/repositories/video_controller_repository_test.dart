import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:openvine/providers/individual_video_providers.dart';
import 'package:openvine/repositories/video_controller_repository.dart';
import 'package:openvine/services/age_verification_service.dart';
import 'package:openvine/services/blossom_auth_service.dart';
import 'package:openvine/services/video_cache_manager.dart';

@GenerateNiceMocks([
  MockSpec<VideoCacheManager>(),
  MockSpec<AgeVerificationService>(),
  MockSpec<BlossomAuthService>(),
  MockSpec<File>(),
])
import 'video_controller_repository_test.mocks.dart';

void main() {
  group('VideoControllerRepository', () {
    late MockVideoCacheManager mockCacheManager;
    late MockAgeVerificationService mockAgeVerificationService;
    late MockBlossomAuthService mockBlossomAuthService;
    late VideoControllerRepository repository;

    setUp(() {
      mockCacheManager = MockVideoCacheManager();
      mockAgeVerificationService = MockAgeVerificationService();
      mockBlossomAuthService = MockBlossomAuthService();

      repository = VideoControllerRepository(
        cacheManager: mockCacheManager,
        ageVerificationService: mockAgeVerificationService,
        blossomAuthService: mockBlossomAuthService,
      );
    });

    tearDown(() {
      repository.dispose();
    });

    group('acquireController', () {
      test('creates network controller when no cache exists', () {
        // Arrange
        when(mockCacheManager.getCachedVideoSync(any)).thenReturn(null);
        when(
          mockAgeVerificationService.isAdultContentVerified,
        ).thenReturn(false);

        final params = VideoControllerParams(
          videoId: 'test-video-id',
          videoUrl: 'https://example.com/video.mp4',
        );

        // Act
        final result = repository.acquireController(params);

        // Assert
        expect(result.controller, isNotNull);
        expect(result.isFromCache, isFalse);
        expect(result.wasExisting, isFalse);
        expect(result.videoUrl, equals('https://example.com/video.mp4'));
        expect(repository.activeCount, equals(1));
      });

      test('returns existing controller when already acquired', () {
        // Arrange
        when(mockCacheManager.getCachedVideoSync(any)).thenReturn(null);
        when(
          mockAgeVerificationService.isAdultContentVerified,
        ).thenReturn(false);

        final params = VideoControllerParams(
          videoId: 'test-video-id',
          videoUrl: 'https://example.com/video.mp4',
        );

        // Act - acquire twice
        final result1 = repository.acquireController(params);
        final result2 = repository.acquireController(params);

        // Assert
        expect(result2.wasExisting, isTrue);
        expect(result2.controller, same(result1.controller));
        expect(repository.activeCount, equals(1)); // Only one in pool
      });

      test('normalizes .bin URL to .mp4 based on MIME type', () {
        // Arrange
        when(mockCacheManager.getCachedVideoSync(any)).thenReturn(null);
        when(
          mockAgeVerificationService.isAdultContentVerified,
        ).thenReturn(false);

        final mockVideoEvent = _MockVideoEvent(mimeType: 'video/mp4');
        final params = VideoControllerParams(
          videoId: 'test-video-id',
          videoUrl: 'https://example.com/abc123.bin',
          videoEvent: mockVideoEvent,
        );

        // Act
        final result = repository.acquireController(params);

        // Assert
        expect(result.videoUrl, equals('https://example.com/abc123.mp4'));
      });

      test('normalizes .bin URL to .webm based on MIME type', () {
        // Arrange
        when(mockCacheManager.getCachedVideoSync(any)).thenReturn(null);
        when(
          mockAgeVerificationService.isAdultContentVerified,
        ).thenReturn(false);

        final mockVideoEvent = _MockVideoEvent(mimeType: 'video/webm');
        final params = VideoControllerParams(
          videoId: 'test-video-id',
          videoUrl: 'https://example.com/abc123.bin',
          videoEvent: mockVideoEvent,
        );

        // Act
        final result = repository.acquireController(params);

        // Assert
        expect(result.videoUrl, equals('https://example.com/abc123.webm'));
      });

      test('does not normalize non-.bin URLs', () {
        // Arrange
        when(mockCacheManager.getCachedVideoSync(any)).thenReturn(null);
        when(
          mockAgeVerificationService.isAdultContentVerified,
        ).thenReturn(false);

        final params = VideoControllerParams(
          videoId: 'test-video-id',
          videoUrl: 'https://example.com/video.mp4',
        );

        // Act
        final result = repository.acquireController(params);

        // Assert
        expect(result.videoUrl, equals('https://example.com/video.mp4'));
      });
    });

    group('pool management', () {
      test('tracks active count correctly', () {
        // Arrange
        when(mockCacheManager.getCachedVideoSync(any)).thenReturn(null);
        when(
          mockAgeVerificationService.isAdultContentVerified,
        ).thenReturn(false);

        // Act & Assert
        expect(repository.activeCount, equals(0));
        expect(repository.availableSlots, equals(4));
        expect(repository.isAtLimit, isFalse);

        repository.acquireController(
          VideoControllerParams(
            videoId: 'video-1',
            videoUrl: 'https://example.com/1.mp4',
          ),
        );
        expect(repository.activeCount, equals(1));
        expect(repository.availableSlots, equals(3));

        repository.acquireController(
          VideoControllerParams(
            videoId: 'video-2',
            videoUrl: 'https://example.com/2.mp4',
          ),
        );
        expect(repository.activeCount, equals(2));
        expect(repository.availableSlots, equals(2));
      });

      test('evicts LRU controller when at capacity', () {
        // Arrange
        when(mockCacheManager.getCachedVideoSync(any)).thenReturn(null);
        when(
          mockAgeVerificationService.isAdultContentVerified,
        ).thenReturn(false);

        // Fill up the pool (4 controllers)
        for (int i = 1; i <= 4; i++) {
          final result = repository.acquireController(
            VideoControllerParams(
              videoId: 'video-$i',
              videoUrl: 'https://example.com/$i.mp4',
            ),
          );
          // Mark as initialized so they can be evicted
          repository.markInitialized('video-$i');
          expect(result.wasExisting, isFalse);
        }

        expect(repository.activeCount, equals(4));
        expect(repository.isAtLimit, isTrue);

        // Act - add one more, should evict video-1 (LRU)
        final newResult = repository.acquireController(
          VideoControllerParams(
            videoId: 'video-5',
            videoUrl: 'https://example.com/5.mp4',
          ),
        );

        // Assert
        expect(newResult.wasExisting, isFalse);
        expect(repository.activeCount, equals(4)); // Still at limit
        expect(repository.hasController('video-1'), isFalse); // Evicted
        expect(repository.hasController('video-5'), isTrue); // New one added
      });

      test('does not evict currently playing controller', () {
        // Arrange
        when(mockCacheManager.getCachedVideoSync(any)).thenReturn(null);
        when(
          mockAgeVerificationService.isAdultContentVerified,
        ).thenReturn(false);

        // Fill up the pool
        for (int i = 1; i <= 4; i++) {
          repository.acquireController(
            VideoControllerParams(
              videoId: 'video-$i',
              videoUrl: 'https://example.com/$i.mp4',
            ),
          );
          repository.markInitialized('video-$i');
        }

        // Mark video-1 as playing (would normally be LRU candidate)
        repository.markPlaying('video-1');

        // Act - add one more
        repository.acquireController(
          VideoControllerParams(
            videoId: 'video-5',
            videoUrl: 'https://example.com/5.mp4',
          ),
        );

        // Assert - video-1 should NOT be evicted because it's playing
        expect(repository.hasController('video-1'), isTrue);
        // video-2 should be evicted instead (next LRU)
        expect(repository.hasController('video-2'), isFalse);
      });

      test('does not evict controllers still initializing', () {
        // Arrange
        when(mockCacheManager.getCachedVideoSync(any)).thenReturn(null);
        when(
          mockAgeVerificationService.isAdultContentVerified,
        ).thenReturn(false);

        // Fill up the pool but don't mark video-1 as initialized
        repository.acquireController(
          VideoControllerParams(
            videoId: 'video-1',
            videoUrl: 'https://example.com/1.mp4',
          ),
        );
        // video-1 is NOT marked as initialized

        for (int i = 2; i <= 4; i++) {
          repository.acquireController(
            VideoControllerParams(
              videoId: 'video-$i',
              videoUrl: 'https://example.com/$i.mp4',
            ),
          );
          repository.markInitialized('video-$i');
        }

        // Act - add one more
        repository.acquireController(
          VideoControllerParams(
            videoId: 'video-5',
            videoUrl: 'https://example.com/5.mp4',
          ),
        );

        // Assert - video-1 should NOT be evicted because it's initializing
        expect(repository.hasController('video-1'), isTrue);
        // video-2 should be evicted instead
        expect(repository.hasController('video-2'), isFalse);
      });
    });

    group('releaseController', () {
      test('removes controller from repository', () {
        // Arrange
        when(mockCacheManager.getCachedVideoSync(any)).thenReturn(null);
        when(
          mockAgeVerificationService.isAdultContentVerified,
        ).thenReturn(false);

        final params = VideoControllerParams(
          videoId: 'test-video-id',
          videoUrl: 'https://example.com/video.mp4',
        );

        repository.acquireController(params);
        expect(repository.activeCount, equals(1));

        // Act
        repository.releaseController('test-video-id');

        // Assert
        expect(repository.activeCount, equals(0));
        expect(repository.hasController('test-video-id'), isFalse);
      });

      test('clears currently playing if released', () {
        // Arrange
        when(mockCacheManager.getCachedVideoSync(any)).thenReturn(null);
        when(
          mockAgeVerificationService.isAdultContentVerified,
        ).thenReturn(false);

        repository.acquireController(
          VideoControllerParams(
            videoId: 'test-video-id',
            videoUrl: 'https://example.com/video.mp4',
          ),
        );
        repository.markPlaying('test-video-id');
        expect(repository.currentlyPlayingVideoId, equals('test-video-id'));

        // Act
        repository.releaseController('test-video-id');

        // Assert
        expect(repository.currentlyPlayingVideoId, isNull);
      });
    });

    group('markPlaying and markNotPlaying', () {
      test('updates currently playing video', () {
        // Arrange
        when(mockCacheManager.getCachedVideoSync(any)).thenReturn(null);
        when(
          mockAgeVerificationService.isAdultContentVerified,
        ).thenReturn(false);

        repository.acquireController(
          VideoControllerParams(
            videoId: 'video-1',
            videoUrl: 'https://example.com/1.mp4',
          ),
        );
        repository.acquireController(
          VideoControllerParams(
            videoId: 'video-2',
            videoUrl: 'https://example.com/2.mp4',
          ),
        );

        // Act & Assert
        expect(repository.currentlyPlayingVideoId, isNull);

        repository.markPlaying('video-1');
        expect(repository.currentlyPlayingVideoId, equals('video-1'));

        repository.markPlaying('video-2');
        expect(repository.currentlyPlayingVideoId, equals('video-2'));

        repository.markNotPlaying('video-2');
        expect(repository.currentlyPlayingVideoId, isNull);
      });
    });

    group('shouldCacheVideo', () {
      test('returns false when video is already cached', () {
        // Arrange
        final mockFile = MockFile();
        when(mockFile.existsSync()).thenReturn(true);
        when(mockCacheManager.getCachedVideoSync(any)).thenReturn(mockFile);

        final params = VideoControllerParams(
          videoId: 'test-video-id',
          videoUrl: 'https://example.com/video.mp4',
        );

        // Act
        final shouldCache = repository.shouldCacheVideo(params);

        // Assert
        expect(shouldCache, isFalse);
      });

      test('returns true when video is not cached', () {
        // Arrange
        when(mockCacheManager.getCachedVideoSync(any)).thenReturn(null);

        final params = VideoControllerParams(
          videoId: 'test-video-id',
          videoUrl: 'https://example.com/video.mp4',
        );

        // Act
        final shouldCache = repository.shouldCacheVideo(params);

        // Assert
        expect(shouldCache, isTrue);
      });

      test('returns true when cached file does not exist', () {
        // Arrange
        final mockFile = MockFile();
        when(mockFile.existsSync()).thenReturn(false);
        when(mockCacheManager.getCachedVideoSync(any)).thenReturn(mockFile);

        final params = VideoControllerParams(
          videoId: 'test-video-id',
          videoUrl: 'https://example.com/video.mp4',
        );

        // Act
        final shouldCache = repository.shouldCacheVideo(params);

        // Assert
        expect(shouldCache, isTrue);
      });
    });

    group('cacheAuthHeaders', () {
      test('does not cache when user has not verified adult content', () async {
        // Arrange
        when(
          mockAgeVerificationService.isAdultContentVerified,
        ).thenReturn(false);

        final params = VideoControllerParams(
          videoId: 'test-video-id',
          videoUrl: 'https://example.com/video.mp4',
        );

        // Act
        await repository.cacheAuthHeaders(params);

        // Assert
        verifyNever(
          mockBlossomAuthService.createGetAuthHeader(
            sha256Hash: anyNamed('sha256Hash'),
            serverUrl: anyNamed('serverUrl'),
          ),
        );
      });

      test('caches auth headers when conditions are met', () async {
        // Arrange
        when(
          mockAgeVerificationService.isAdultContentVerified,
        ).thenReturn(true);
        when(mockBlossomAuthService.canCreateHeaders).thenReturn(true);
        when(
          mockBlossomAuthService.createGetAuthHeader(
            sha256Hash: anyNamed('sha256Hash'),
            serverUrl: anyNamed('serverUrl'),
          ),
        ).thenAnswer((_) async => 'Bearer new-token');
        when(mockCacheManager.getCachedVideoSync(any)).thenReturn(null);

        final mockVideoEvent = _MockVideoEvent(sha256: 'abc123');
        final params = VideoControllerParams(
          videoId: 'test-video-id',
          videoUrl: 'https://example.com/video.mp4',
          videoEvent: mockVideoEvent,
        );

        // Act
        await repository.cacheAuthHeaders(params);

        // Assert - verify the method was called
        verify(
          mockBlossomAuthService.createGetAuthHeader(
            sha256Hash: 'abc123',
            serverUrl: 'https://example.com',
          ),
        ).called(1);
      });
    });

    group('clear', () {
      test('removes all controllers', () {
        // Arrange
        when(mockCacheManager.getCachedVideoSync(any)).thenReturn(null);
        when(
          mockAgeVerificationService.isAdultContentVerified,
        ).thenReturn(false);

        for (int i = 1; i <= 3; i++) {
          repository.acquireController(
            VideoControllerParams(
              videoId: 'video-$i',
              videoUrl: 'https://example.com/$i.mp4',
            ),
          );
        }
        repository.markPlaying('video-1');

        expect(repository.activeCount, equals(3));
        expect(repository.currentlyPlayingVideoId, equals('video-1'));

        // Act
        repository.clear();

        // Assert
        expect(repository.activeCount, equals(0));
        expect(repository.currentlyPlayingVideoId, isNull);
        expect(repository.hasController('video-1'), isFalse);
        expect(repository.hasController('video-2'), isFalse);
        expect(repository.hasController('video-3'), isFalse);
      });
    });

    group('toString', () {
      test('returns descriptive string', () {
        // Arrange
        when(mockCacheManager.getCachedVideoSync(any)).thenReturn(null);
        when(
          mockAgeVerificationService.isAdultContentVerified,
        ).thenReturn(false);

        repository.acquireController(
          VideoControllerParams(
            videoId: 'test-video',
            videoUrl: 'https://example.com/video.mp4',
          ),
        );
        repository.markPlaying('test-video');

        // Act
        final result = repository.toString();

        // Assert
        expect(
          result,
          equals('VideoControllerRepository(active: 1/4, playing: test-video)'),
        );
      });
    });
  });
}

/// Mock video event for testing
class _MockVideoEvent {
  _MockVideoEvent({this.mimeType, this.sha256});

  final String? mimeType;
  final String? sha256;
}
