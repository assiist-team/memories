import 'package:flutter_test/flutter_test.dart';
import 'package:memories/models/queued_memory.dart';
import 'package:memories/models/timeline_memory.dart';
import 'package:memories/services/offline_queue_to_timeline_adapter.dart';

void main() {
  group('OfflineQueueToTimelineAdapter', () {
    group('fromQueuedMemory', () {
      test('converts queued moment with all fields', () {
        final queued = QueuedMemory(
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

        final result = OfflineQueueToTimelineAdapter.fromQueuedMemory(queued);

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
        final queued = QueuedMemory(
          localId: 'local-456',
          memoryType: 'moment',
          inputText: 'Syncing moment',
          createdAt: DateTime(2024, 6, 15, 10, 30),
          status: 'syncing',
        );

        final result = OfflineQueueToTimelineAdapter.fromQueuedMemory(queued);

        expect(result.offlineSyncStatus, equals(OfflineSyncStatus.syncing));
        expect(result.isOfflineQueued, isTrue);
      });

      test('converts queued moment with failed status', () {
        final queued = QueuedMemory(
          localId: 'local-789',
          memoryType: 'moment',
          inputText: 'Failed moment',
          createdAt: DateTime(2024, 6, 15, 10, 30),
          status: 'failed',
        );

        final result = OfflineQueueToTimelineAdapter.fromQueuedMemory(queued);

        expect(result.offlineSyncStatus, equals(OfflineSyncStatus.failed));
      });

      test('converts queued moment with completed status', () {
        final queued = QueuedMemory(
          localId: 'local-999',
          memoryType: 'moment',
          inputText: 'Completed moment',
          createdAt: DateTime(2024, 6, 15, 10, 30),
          status: 'completed',
          serverMemoryId: 'server-123',
        );

        final result = OfflineQueueToTimelineAdapter.fromQueuedMemory(queued);

        expect(result.offlineSyncStatus, equals(OfflineSyncStatus.synced));
        expect(result.serverId, equals('server-123'));
        expect(result.effectiveId, equals('server-123'));
      });

      test('generates title from input text', () {
        final queued = QueuedMemory(
          localId: 'local-111',
          memoryType: 'moment',
          inputText: 'First line\nSecond line',
          createdAt: DateTime(2024, 6, 15, 10, 30),
        );

        final result = OfflineQueueToTimelineAdapter.fromQueuedMemory(queued);

        expect(result.title, equals('First line'));
      });

      test('generates fallback title when input text is empty', () {
        final queued = QueuedMemory(
          localId: 'local-222',
          memoryType: 'story',
          createdAt: DateTime(2024, 6, 15, 10, 30),
        );

        final result = OfflineQueueToTimelineAdapter.fromQueuedMemory(queued);

        expect(result.title, equals('Untitled Story'));
      });

      test('handles video as primary media', () {
        final queued = QueuedMemory(
          localId: 'local-333',
          memoryType: 'moment',
          videoPaths: ['/path/to/video.mp4'],
          createdAt: DateTime(2024, 6, 15, 10, 30),
        );

        final result = OfflineQueueToTimelineAdapter.fromQueuedMemory(queued);

        expect(result.primaryMedia, isNotNull);
        expect(result.primaryMedia!.type, equals('video'));
        expect(result.primaryMedia!.url, equals('/path/to/video.mp4'));
      });

      test('extracts date components correctly', () {
        final queued = QueuedMemory(
          localId: 'local-444',
          memoryType: 'moment',
          capturedAt: DateTime(2024, 6, 15, 10, 30),
          createdAt: DateTime(2024, 6, 15, 10, 30),
        );

        final result = OfflineQueueToTimelineAdapter.fromQueuedMemory(queued);

        expect(result.year, equals(2024));
        expect(result.month, equals(6));
        expect(result.day, equals(15));
        expect(result.season, equals('Summer'));
      });

      test('uses createdAt when capturedAt is null', () {
        final queued = QueuedMemory(
          localId: 'local-555',
          memoryType: 'moment',
          createdAt: DateTime(2024, 12, 25, 10, 30),
        );

        final result = OfflineQueueToTimelineAdapter.fromQueuedMemory(queued);

        expect(result.capturedAt, equals(DateTime(2024, 12, 25, 10, 30)));
        expect(result.season, equals('Winter'));
      });
    });

    // Story-specific behavior is now represented on QueuedMemory and mapped
    // through the same fromQueuedMemory path based on memoryType.
  });
}

