import 'package:flutter_test/flutter_test.dart';
import 'package:memories/models/local_memory_preview.dart';
import 'package:memories/models/memory_type.dart';
import 'package:memories/models/timeline_moment.dart';
import 'package:memories/services/preview_index_to_timeline_adapter.dart';

void main() {
  group('PreviewIndexToTimelineAdapter', () {
    group('fromPreview', () {
      test('converts preview with isDetailCachedLocally false', () {
        final preview = LocalMemoryPreview(
          serverId: 'server-123',
          memoryType: MemoryType.moment,
          titleOrFirstLine: 'Test Moment',
          capturedAt: DateTime(2024, 6, 15, 10, 30),
          isDetailCachedLocally: false,
        );

        final result = PreviewIndexToTimelineAdapter.fromPreview(preview);

        expect(result.id, equals('server-123'));
        expect(result.serverId, equals('server-123'));
        expect(result.localId, isNull);
        expect(result.isOfflineQueued, isFalse);
        expect(result.isPreviewOnly, isTrue);
        expect(result.isDetailCachedLocally, isFalse);
        expect(result.isAvailableOffline, isFalse);
        expect(result.offlineSyncStatus, equals(OfflineSyncStatus.synced));
        expect(result.memoryType, equals('moment'));
        expect(result.title, equals('Test Moment'));
        expect(result.inputText, isNull);
        expect(result.processedText, isNull);
        expect(result.tags, isEmpty);
        expect(result.primaryMedia, isNull);
        expect(result.snippetText, equals('Test Moment'));
      });

      test('converts preview with isDetailCachedLocally true', () {
        final preview = LocalMemoryPreview(
          serverId: 'server-456',
          memoryType: MemoryType.story,
          titleOrFirstLine: 'Test Story',
          capturedAt: DateTime(2024, 6, 15, 10, 30),
          isDetailCachedLocally: true,
        );

        final result = PreviewIndexToTimelineAdapter.fromPreview(preview);

        expect(result.isPreviewOnly, isFalse);
        expect(result.isDetailCachedLocally, isTrue);
        expect(result.isAvailableOffline, isTrue);
        expect(result.memoryType, equals('story'));
      });

      test('extracts date components correctly', () {
        final preview = LocalMemoryPreview(
          serverId: 'server-789',
          memoryType: MemoryType.memento,
          titleOrFirstLine: 'Test Memento',
          capturedAt: DateTime(2024, 12, 25, 10, 30),
        );

        final result = PreviewIndexToTimelineAdapter.fromPreview(preview);

        expect(result.year, equals(2024));
        expect(result.month, equals(12));
        expect(result.day, equals(25));
        expect(result.season, equals('Winter'));
        expect(result.capturedAt, equals(DateTime(2024, 12, 25, 10, 30)));
      });

      test('uses capturedAt as createdAt fallback', () {
        final capturedAt = DateTime(2024, 6, 15, 10, 30);
        final preview = LocalMemoryPreview(
          serverId: 'server-999',
          memoryType: MemoryType.moment,
          titleOrFirstLine: 'Test',
          capturedAt: capturedAt,
        );

        final result = PreviewIndexToTimelineAdapter.fromPreview(preview);

        expect(result.createdAt, equals(capturedAt));
      });

      test('handles all memory types', () {
        final types = [
          MemoryType.moment,
          MemoryType.story,
          MemoryType.memento,
        ];

        for (final type in types) {
          final preview = LocalMemoryPreview(
            serverId: 'server-${type.name}',
            memoryType: type,
            titleOrFirstLine: 'Test ${type.name}',
            capturedAt: DateTime(2024, 6, 15, 10, 30),
          );

          final result = PreviewIndexToTimelineAdapter.fromPreview(preview);

          expect(result.memoryType, equals(type.apiValue));
        }
      });

      test('sets snippetText to titleOrFirstLine', () {
        final preview = LocalMemoryPreview(
          serverId: 'server-111',
          memoryType: MemoryType.moment,
          titleOrFirstLine: 'My Custom Title',
          capturedAt: DateTime(2024, 6, 15, 10, 30),
        );

        final result = PreviewIndexToTimelineAdapter.fromPreview(preview);

        expect(result.snippetText, equals('My Custom Title'));
        expect(result.title, equals('My Custom Title'));
      });

      test('effectiveId uses serverId', () {
        final preview = LocalMemoryPreview(
          serverId: 'server-effective',
          memoryType: MemoryType.moment,
          titleOrFirstLine: 'Test',
          capturedAt: DateTime(2024, 6, 15, 10, 30),
        );

        final result = PreviewIndexToTimelineAdapter.fromPreview(preview);

        expect(result.effectiveId, equals('server-effective'));
        expect(result.id, equals('server-effective'));
        expect(result.serverId, equals('server-effective'));
      });
    });
  });
}

