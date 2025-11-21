import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:memories/providers/offline_memory_detail_provider.dart';
import 'package:memories/services/offline_queue_service.dart';
import 'package:memories/services/offline_story_queue_service.dart';
import 'package:memories/models/queued_moment.dart';
import 'package:memories/models/queued_story.dart';
import 'package:memories/models/memory_detail.dart';

// Mock classes
class MockOfflineQueueService extends Mock implements OfflineQueueService {}

class MockOfflineStoryQueueService extends Mock implements OfflineStoryQueueService {}

void main() {
  group('OfflineMemoryDetailNotifier', () {
    late MockOfflineQueueService mockQueueService;
    late MockOfflineStoryQueueService mockStoryQueueService;
    late ProviderContainer container;

    setUp(() {
      mockQueueService = MockOfflineQueueService();
      mockStoryQueueService = MockOfflineStoryQueueService();

      container = ProviderContainer(
        overrides: [
          offlineQueueServiceProvider.overrideWithValue(mockQueueService),
          offlineStoryQueueServiceProvider.overrideWithValue(mockStoryQueueService),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    group('Loading queued moments', () {
      test('loads a queued moment by localId', () async {
        final queuedMoment = QueuedMoment(
          localId: 'local-123',
          memoryType: 'moment',
          inputText: 'This is a test moment',
          photoPaths: ['/path/to/photo1.jpg', '/path/to/photo2.jpg'],
          videoPaths: ['/path/to/video.mp4'],
          tags: ['test', 'moment'],
          latitude: 37.7749,
          longitude: -122.4194,
          locationStatus: 'granted',
          capturedAt: DateTime(2024, 6, 15, 10, 30),
          createdAt: DateTime(2024, 6, 15, 10, 30),
          status: 'queued',
        );

        when(() => mockQueueService.getByLocalId('local-123'))
            .thenAnswer((_) async => queuedMoment);
        when(() => mockStoryQueueService.getByLocalId('local-123'))
            .thenAnswer((_) async => null);

        final provider = offlineMemoryDetailNotifierProvider('local-123');
        final result = await container.read(provider.future);

        expect(result.id, equals('local-123'));
        expect(result.memoryType, equals('moment'));
        expect(result.inputText, equals('This is a test moment'));
        expect(result.processedText, isNull);
        expect(result.generatedTitle, isNull);
        expect(result.tags, equals(['test', 'moment']));
        expect(result.capturedAt, equals(DateTime(2024, 6, 15, 10, 30)));
        expect(result.createdAt, equals(DateTime(2024, 6, 15, 10, 30)));
        expect(result.updatedAt, equals(DateTime(2024, 6, 15, 10, 30)));
        expect(result.userId, isEmpty);
        expect(result.publicShareToken, isNull);
        expect(result.relatedStories, isEmpty);
        expect(result.relatedMementos, isEmpty);

        // Check photos
        expect(result.photos.length, equals(2));
        expect(result.photos[0].url, equals('/path/to/photo1.jpg'));
        expect(result.photos[0].index, equals(0));
        expect(result.photos[1].url, equals('/path/to/photo2.jpg'));
        expect(result.photos[1].index, equals(1));

        // Check videos
        expect(result.videos.length, equals(1));
        expect(result.videos[0].url, equals('/path/to/video.mp4'));
        expect(result.videos[0].index, equals(0));

        // Check location
        expect(result.locationData, isNotNull);
        expect(result.locationData!.latitude, equals(37.7749));
        expect(result.locationData!.longitude, equals(-122.4194));
        expect(result.locationData!.status, equals('granted'));
        expect(result.locationData!.city, isNull);
        expect(result.locationData!.state, isNull);

        // Check title generation
        expect(result.title, equals('This is a test moment'));
      });

      test('loads a queued memento', () async {
        final queuedMemento = QueuedMoment(
          localId: 'local-memento-123',
          memoryType: 'memento',
          inputText: 'First line\nSecond line',
          photoPaths: ['/path/to/photo.jpg'],
          tags: ['vacation'],
          capturedAt: DateTime(2024, 6, 15, 10, 30),
          createdAt: DateTime(2024, 6, 15, 10, 30),
        );

        when(() => mockQueueService.getByLocalId('local-memento-123'))
            .thenAnswer((_) async => queuedMemento);
        when(() => mockStoryQueueService.getByLocalId('local-memento-123'))
            .thenAnswer((_) async => null);

        final provider = offlineMemoryDetailNotifierProvider('local-memento-123');
        final result = await container.read(provider.future);

        expect(result.memoryType, equals('memento'));
        expect(result.title, equals('First line')); // First line used as title
      });

      test('generates fallback title when input text is empty', () async {
        final queuedMoment = QueuedMoment(
          localId: 'local-empty',
          memoryType: 'moment',
          createdAt: DateTime(2024, 6, 15, 10, 30),
        );

        when(() => mockQueueService.getByLocalId('local-empty'))
            .thenAnswer((_) async => queuedMoment);
        when(() => mockStoryQueueService.getByLocalId('local-empty'))
            .thenAnswer((_) async => null);

        final provider = offlineMemoryDetailNotifierProvider('local-empty');
        final result = await container.read(provider.future);

        expect(result.title, equals('Untitled Moment'));
      });

      test('uses createdAt when capturedAt is null', () async {
        final queuedMoment = QueuedMoment(
          localId: 'local-no-capture',
          memoryType: 'moment',
          inputText: 'Test',
          createdAt: DateTime(2024, 12, 25, 10, 30),
        );

        when(() => mockQueueService.getByLocalId('local-no-capture'))
            .thenAnswer((_) async => queuedMoment);
        when(() => mockStoryQueueService.getByLocalId('local-no-capture'))
            .thenAnswer((_) async => null);

        final provider = offlineMemoryDetailNotifierProvider('local-no-capture');
        final result = await container.read(provider.future);

        expect(result.capturedAt, equals(DateTime(2024, 12, 25, 10, 30)));
      });
    });

    group('Loading queued stories', () {
      test('loads a queued story by localId', () async {
        final queuedStory = QueuedStory(
          localId: 'local-story-123',
          memoryType: 'story',
          inputText: 'This is a test story',
          audioPath: '/path/to/audio.m4a',
          audioDuration: 120.5,
          photoPaths: ['/path/to/photo.jpg'],
          videoPaths: [],
          tags: ['test', 'story'],
          latitude: 37.7749,
          longitude: -122.4194,
          locationStatus: 'granted',
          capturedAt: DateTime(2024, 6, 15, 10, 30),
          createdAt: DateTime(2024, 6, 15, 10, 30),
          status: 'queued',
        );

        when(() => mockQueueService.getByLocalId('local-story-123'))
            .thenAnswer((_) async => null);
        when(() => mockStoryQueueService.getByLocalId('local-story-123'))
            .thenAnswer((_) async => queuedStory);

        final provider = offlineMemoryDetailNotifierProvider('local-story-123');
        final result = await container.read(provider.future);

        expect(result.id, equals('local-story-123'));
        expect(result.memoryType, equals('story'));
        expect(result.inputText, equals('This is a test story'));
        expect(result.processedText, isNull);
        expect(result.generatedTitle, isNull);
        expect(result.tags, equals(['test', 'story']));
        expect(result.capturedAt, equals(DateTime(2024, 6, 15, 10, 30)));
        expect(result.photos.length, equals(1));
        expect(result.photos[0].url, equals('/path/to/photo.jpg'));
        expect(result.title, equals('This is a test story'));
      });

      test('generates fallback title for story when input text is empty', () async {
        final queuedStory = QueuedStory(
          localId: 'local-story-empty',
          memoryType: 'story',
          createdAt: DateTime(2024, 6, 15, 10, 30),
        );

        when(() => mockQueueService.getByLocalId('local-story-empty'))
            .thenAnswer((_) async => null);
        when(() => mockStoryQueueService.getByLocalId('local-story-empty'))
            .thenAnswer((_) async => queuedStory);

        final provider = offlineMemoryDetailNotifierProvider('local-story-empty');
        final result = await container.read(provider.future);

        expect(result.title, equals('Untitled Story'));
      });
    });

    group('Error handling', () {
      test('throws when localId does not exist in any queue', () async {
        when(() => mockQueueService.getByLocalId('non-existent'))
            .thenAnswer((_) async => null);
        when(() => mockStoryQueueService.getByLocalId('non-existent'))
            .thenAnswer((_) async => null);

        final provider = offlineMemoryDetailNotifierProvider('non-existent');

        expect(
          () => container.read(provider.future),
          throwsA(isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Offline queued memory not found: non-existent'),
          )),
        );
      });
    });

    group('Media handling', () {
      test('handles memory with no media', () async {
        final queuedMoment = QueuedMoment(
          localId: 'local-no-media',
          memoryType: 'moment',
          inputText: 'Text only moment',
          photoPaths: [],
          videoPaths: [],
          createdAt: DateTime(2024, 6, 15, 10, 30),
        );

        when(() => mockQueueService.getByLocalId('local-no-media'))
            .thenAnswer((_) async => queuedMoment);
        when(() => mockStoryQueueService.getByLocalId('local-no-media'))
            .thenAnswer((_) async => null);

        final provider = offlineMemoryDetailNotifierProvider('local-no-media');
        final result = await container.read(provider.future);

        expect(result.photos, isEmpty);
        expect(result.videos, isEmpty);
      });

      test('handles memory with location but no city/state', () async {
        final queuedMoment = QueuedMoment(
          localId: 'local-location',
          memoryType: 'moment',
          inputText: 'Test',
          latitude: 37.7749,
          longitude: -122.4194,
          locationStatus: 'granted',
          createdAt: DateTime(2024, 6, 15, 10, 30),
        );

        when(() => mockQueueService.getByLocalId('local-location'))
            .thenAnswer((_) async => queuedMoment);
        when(() => mockStoryQueueService.getByLocalId('local-location'))
            .thenAnswer((_) async => null);

        final provider = offlineMemoryDetailNotifierProvider('local-location');
        final result = await container.read(provider.future);

        expect(result.locationData, isNotNull);
        expect(result.locationData!.latitude, equals(37.7749));
        expect(result.locationData!.longitude, equals(-122.4194));
        expect(result.locationData!.city, isNull);
        expect(result.locationData!.state, isNull);
      });

      test('handles memory with no location', () async {
        final queuedMoment = QueuedMoment(
          localId: 'local-no-location',
          memoryType: 'moment',
          inputText: 'Test',
          createdAt: DateTime(2024, 6, 15, 10, 30),
        );

        when(() => mockQueueService.getByLocalId('local-no-location'))
            .thenAnswer((_) async => queuedMoment);
        when(() => mockStoryQueueService.getByLocalId('local-no-location'))
            .thenAnswer((_) async => null);

        final provider = offlineMemoryDetailNotifierProvider('local-no-location');
        final result = await container.read(provider.future);

        expect(result.locationData, isNull);
      });
    });
  });
}

