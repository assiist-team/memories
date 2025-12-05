import 'package:flutter_test/flutter_test.dart';
import 'package:memories/models/memory_detail.dart';
import 'package:memories/models/timeline_memory.dart';

void main() {
  group('TimelineMemory.displayTitle', () {
    final now = DateTime(2025, 1, 1);

    TimelineMemory buildMemory({
      String title = '',
      String? generatedTitle,
      String? processedText,
      String? inputText,
      String memoryType = 'story',
    }) {
      return TimelineMemory(
        id: 'timeline-1',
        userId: 'user',
        title: title,
        inputText: inputText,
        processedText: processedText,
        generatedTitle: generatedTitle,
        tags: const [],
        memoryType: memoryType,
        capturedAt: now,
        createdAt: now,
        memoryDate: now,
        year: now.year,
        season: 'winter',
        month: now.month,
        day: now.day,
        primaryMedia: null,
        snippetText: null,
        memoryLocationData: null,
        nextCursorCapturedAt: null,
        nextCursorId: null,
        isOfflineQueued: false,
        isPreviewOnly: false,
        isDetailCachedLocally: false,
        localId: null,
        serverId: 'timeline-1',
        offlineSyncStatus: OfflineSyncStatus.synced,
      );
    }

    test('prefers generated title when available', () {
      final memory = buildMemory(
        generatedTitle: 'Generated',
        title: 'Fallback',
      );
      expect(memory.displayTitle, 'Generated');
    });

    test('falls back to stored title when generated title missing', () {
      final memory = buildMemory(title: 'Fallback title');
      expect(memory.displayTitle, 'Fallback title');
    });

    test('falls back to processed text when titles missing', () {
      final memory = buildMemory(
        processedText: 'Processed narrative text',
      );
      expect(memory.displayTitle, 'Processed narrative text');
    });

    test('falls back to input text when processed text missing', () {
      final memory = buildMemory(
        inputText: 'Original capture text',
      );
      expect(memory.displayTitle, 'Original capture text');
    });

    test('returns typed untitled label when no text exists', () {
      final story = buildMemory(memoryType: 'story');
      final memento = buildMemory(memoryType: 'memento');
      final moment = buildMemory(memoryType: 'moment');

      expect(story.displayTitle, 'Untitled Story');
      expect(memento.displayTitle, 'Untitled Memento');
      expect(moment.displayTitle, 'Untitled Moment');
    });
  });

  group('MemoryDetail.displayTitle', () {
    final now = DateTime(2025, 2, 2);

    MemoryDetail buildDetail({
      String title = '',
      String? generatedTitle,
      String? processedText,
      String? inputText,
      String memoryType = 'story',
    }) {
      return MemoryDetail(
        id: 'detail-1',
        userId: 'user',
        title: title,
        inputText: inputText,
        processedText: processedText,
        generatedTitle: generatedTitle,
        tags: const [],
        memoryType: memoryType,
        capturedAt: now,
        createdAt: now,
        updatedAt: now,
        memoryDate: now,
        publicShareToken: null,
        locationData: null,
        memoryLocationData: null,
        photos: const [],
        videos: const [],
        relatedStories: const [],
        relatedMementos: const [],
        audioPath: null,
        audioDuration: null,
      );
    }

    test('prefers generated title', () {
      final detail = buildDetail(
        generatedTitle: 'Narrated Title',
        title: 'Manual Title',
      );
      expect(detail.displayTitle, 'Narrated Title');
    });

    test('uses title when generated title missing', () {
      final detail = buildDetail(title: 'Manual Title');
      expect(detail.displayTitle, 'Manual Title');
    });

    test('falls back to processed text, then input text', () {
      final fromProcessed = buildDetail(
        processedText: 'Processed detail text value',
      );
      final fromInput = buildDetail(
        inputText: 'Input-only text value',
      );

      expect(fromProcessed.displayTitle, 'Processed detail text value');
      expect(fromInput.displayTitle, 'Input-only text value');
    });

    test('returns untitled labels by memory type', () {
      final story = buildDetail(memoryType: 'story');
      final memento = buildDetail(memoryType: 'memento');
      final moment = buildDetail(memoryType: 'moment');

      expect(story.displayTitle, 'Untitled Story');
      expect(memento.displayTitle, 'Untitled Memento');
      expect(moment.displayTitle, 'Untitled Moment');
    });
  });
}
