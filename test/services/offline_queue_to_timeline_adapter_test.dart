import 'package:flutter_test/flutter_test.dart';
import 'package:memories/models/queued_moment.dart';
import 'package:memories/models/queued_story.dart';
import 'package:memories/models/timeline_moment.dart';
import 'package:memories/services/offline_queue_to_timeline_adapter.dart';

void main() {
  group('OfflineQueueToTimelineAdapter', () {
    group('fromQueuedMoment', () {
      test('converts queued moment with all fields', () {
        final queued = QueuedMoment(
          localId: 'local-123',
          memoryType: 'moment',
          inputText: 'This is a test moment',
          photoPaths: ['/path/to/photo.jpg'],
          videoPaths: [],
          tags: ['test', 'moment'],
          capturedAt: DateTime(2024, 6, 15, 10, 30),
          createdAt: DateTime(2024, 6, 15, 10, 30),
          status: 'queued',
        );

        final result = OfflineQueueToTimelineAdapter.fromQueuedMoment(queued);

        expect(result.id, equals('local-123'));
        expect(result.localId, equals('local-123'));
        expect(result.serverId, isNull);
        expect(result.isOfflineQueued, isTrue);
        expect(result.isPreviewOnly, isFalse);
        expect(result.isDetailCachedLocally, isTrue);
        expect(result.isAvailableOffline, isTrue);
        expect(result.offlineSyncStatus, equals(OfflineSyncStatus.queued));
        expect(result.memoryType, equals('moment'));
        expect(result.inputText, equals('This is a test moment'));
        expect(result.processedText, isNull);
        expect(result.tags, equals(['test', 'moment']));
        expect(result.capturedAt, equals(DateTime(2024, 6, 15, 10, 30)));
        expect(result.primaryMedia, isNotNull);
        expect(result.primaryMedia!.type, equals('photo'));
        expect(result.primaryMedia!.url, equals('/path/to/photo.jpg'));
      });

      test('converts queued moment with syncing status', () {
        final queued = QueuedMoment(
          localId: 'local-456',
          memoryType: 'moment',
          inputText: 'Syncing moment',
          createdAt: DateTime(2024, 6, 15, 10, 30),
          status: 'syncing',
        );

        final result = OfflineQueueToTimelineAdapter.fromQueuedMoment(queued);

        expect(result.offlineSyncStatus, equals(OfflineSyncStatus.syncing));
        expect(result.isOfflineQueued, isTrue);
      });

      test('converts queued moment with failed status', () {
        final queued = QueuedMoment(
          localId: 'local-789',
          memoryType: 'moment',
          inputText: 'Failed moment',
          createdAt: DateTime(2024, 6, 15, 10, 30),
          status: 'failed',
        );

        final result = OfflineQueueToTimelineAdapter.fromQueuedMoment(queued);

        expect(result.offlineSyncStatus, equals(OfflineSyncStatus.failed));
      });

      test('converts queued moment with completed status', () {
        final queued = QueuedMoment(
          localId: 'local-999',
          memoryType: 'moment',
          inputText: 'Completed moment',
          createdAt: DateTime(2024, 6, 15, 10, 30),
          status: 'completed',
          serverMomentId: 'server-123',
        );

        final result = OfflineQueueToTimelineAdapter.fromQueuedMoment(queued);

        expect(result.offlineSyncStatus, equals(OfflineSyncStatus.synced));
        expect(result.serverId, equals('server-123'));
        expect(result.effectiveId, equals('server-123'));
      });

      test('generates title from input text', () {
        final queued = QueuedMoment(
          localId: 'local-111',
          memoryType: 'moment',
          inputText: 'First line\nSecond line',
          createdAt: DateTime(2024, 6, 15, 10, 30),
        );

        final result = OfflineQueueToTimelineAdapter.fromQueuedMoment(queued);

        expect(result.title, equals('First line'));
      });

      test('generates fallback title when input text is empty', () {
        final queued = QueuedMoment(
          localId: 'local-222',
          memoryType: 'story',
          createdAt: DateTime(2024, 6, 15, 10, 30),
        );

        final result = OfflineQueueToTimelineAdapter.fromQueuedMoment(queued);

        expect(result.title, equals('Untitled Story'));
      });

      test('handles video as primary media', () {
        final queued = QueuedMoment(
          localId: 'local-333',
          memoryType: 'moment',
          videoPaths: ['/path/to/video.mp4'],
          createdAt: DateTime(2024, 6, 15, 10, 30),
        );

        final result = OfflineQueueToTimelineAdapter.fromQueuedMoment(queued);

        expect(result.primaryMedia, isNotNull);
        expect(result.primaryMedia!.type, equals('video'));
        expect(result.primaryMedia!.url, equals('/path/to/video.mp4'));
      });

      test('extracts date components correctly', () {
        final queued = QueuedMoment(
          localId: 'local-444',
          memoryType: 'moment',
          capturedAt: DateTime(2024, 6, 15, 10, 30),
          createdAt: DateTime(2024, 6, 15, 10, 30),
        );

        final result = OfflineQueueToTimelineAdapter.fromQueuedMoment(queued);

        expect(result.year, equals(2024));
        expect(result.month, equals(6));
        expect(result.day, equals(15));
        expect(result.season, equals('Summer'));
      });

      test('uses createdAt when capturedAt is null', () {
        final queued = QueuedMoment(
          localId: 'local-555',
          memoryType: 'moment',
          createdAt: DateTime(2024, 12, 25, 10, 30),
        );

        final result = OfflineQueueToTimelineAdapter.fromQueuedMoment(queued);

        expect(result.capturedAt, equals(DateTime(2024, 12, 25, 10, 30)));
        expect(result.season, equals('Winter'));
      });
    });

    group('fromQueuedStory', () {
      test('converts queued story with audio', () {
        final queued = QueuedStory(
          localId: 'local-story-123',
          memoryType: 'story',
          inputText: 'This is a test story',
          audioPath: '/path/to/audio.m4a',
          audioDuration: 120.5,
          photoPaths: [],
          videoPaths: [],
          tags: ['test', 'story'],
          capturedAt: DateTime(2024, 6, 15, 10, 30),
          createdAt: DateTime(2024, 6, 15, 10, 30),
          status: 'queued',
        );

        final result = OfflineQueueToTimelineAdapter.fromQueuedStory(queued);

        expect(result.id, equals('local-story-123'));
        expect(result.localId, equals('local-story-123'));
        expect(result.isOfflineQueued, isTrue);
        expect(result.isPreviewOnly, isFalse);
        expect(result.isDetailCachedLocally, isTrue);
        expect(result.isAvailableOffline, isTrue);
        expect(result.memoryType, equals('story'));
        expect(result.inputText, equals('This is a test story'));
        expect(result.primaryMedia, isNotNull);
        expect(result.primaryMedia!.url, equals('/path/to/audio.m4a'));
      });

      test('converts queued story with server ID after sync', () {
        final queued = QueuedStory(
          localId: 'local-story-456',
          memoryType: 'story',
          inputText: 'Synced story',
          createdAt: DateTime(2024, 6, 15, 10, 30),
          status: 'completed',
          serverStoryId: 'server-story-123',
        );

        final result = OfflineQueueToTimelineAdapter.fromQueuedStory(queued);

        expect(result.serverId, equals('server-story-123'));
        expect(result.effectiveId, equals('server-story-123'));
        expect(result.offlineSyncStatus, equals(OfflineSyncStatus.synced));
      });

      test('handles story with photos before audio', () {
        final queued = QueuedStory(
          localId: 'local-story-789',
          memoryType: 'story',
          inputText: 'Story with photo',
          photoPaths: ['/path/to/photo.jpg'],
          audioPath: '/path/to/audio.m4a',
          createdAt: DateTime(2024, 6, 15, 10, 30),
        );

        final result = OfflineQueueToTimelineAdapter.fromQueuedStory(queued);

        // Photo should be primary media (checked before audio)
        expect(result.primaryMedia, isNotNull);
        expect(result.primaryMedia!.type, equals('photo'));
        expect(result.primaryMedia!.url, equals('/path/to/photo.jpg'));
      });
    });
  });
}

