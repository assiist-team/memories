import 'package:flutter_test/flutter_test.dart';
import 'package:memories/models/capture_state.dart';
import 'package:memories/models/memory_type.dart';
import 'package:memories/models/queued_moment.dart';
import 'package:memories/models/queued_story.dart';
import 'package:memories/services/offline_queue_service.dart';
import 'package:memories/services/offline_story_queue_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Offline Memory Editing', () {
    late OfflineQueueService queueService;
    late OfflineStoryQueueService storyQueueService;

    setUp(() async {
      // Clear SharedPreferences before each test
      SharedPreferences.setMockInitialValues({});
      queueService = OfflineQueueService();
      storyQueueService = OfflineStoryQueueService();
    });

    group('QueuedMoment.copyWithFromCaptureState', () {
      test('updates text only, preserves sync metadata', () {
        final original = QueuedMoment(
          localId: 'local-123',
          memoryType: 'moment',
          inputText: 'Original text',
          photoPaths: ['/path/to/photo1.jpg'],
          tags: ['tag1'],
          latitude: 40.7128,
          longitude: -74.0060,
          status: 'queued',
          retryCount: 2,
          createdAt: DateTime(2024, 6, 15, 10, 30),
          serverMomentId: null,
        );

        final updatedState = CaptureState(
          memoryType: MemoryType.moment,
          inputText: 'Updated text',
          photoPaths: [], // No new photos
          tags: ['tag1'], // Same tags
          latitude: 40.7128, // Same location
          longitude: -74.0060,
        );

        final updated = original.copyWithFromCaptureState(
          state: updatedState,
        );

        expect(updated.inputText, equals('Updated text'));
        expect(updated.photoPaths, equals(['/path/to/photo1.jpg'])); // Preserved
        expect(updated.tags, equals(['tag1'])); // Preserved
        expect(updated.latitude, equals(40.7128)); // Preserved
        expect(updated.longitude, equals(-74.0060)); // Preserved
        expect(updated.status, equals('queued')); // Preserved
        expect(updated.retryCount, equals(2)); // Preserved
        expect(updated.createdAt, equals(DateTime(2024, 6, 15, 10, 30))); // Preserved
        expect(updated.serverMomentId, isNull); // Preserved
      });

      test('updates tags, preserves other fields', () {
        final original = QueuedMoment(
          localId: 'local-123',
          memoryType: 'moment',
          inputText: 'Test text',
          tags: ['old-tag'],
          createdAt: DateTime(2024, 6, 15, 10, 30),
        );

        final updatedState = CaptureState(
          memoryType: MemoryType.moment,
          inputText: 'Test text',
          tags: ['new-tag1', 'new-tag2'],
        );

        final updated = original.copyWithFromCaptureState(
          state: updatedState,
        );

        expect(updated.tags, equals(['new-tag1', 'new-tag2']));
        expect(updated.inputText, equals('Test text')); // Preserved
      });

      test('adds new photos, preserves existing', () {
        final original = QueuedMoment(
          localId: 'local-123',
          memoryType: 'moment',
          photoPaths: ['/existing/photo1.jpg'],
          createdAt: DateTime(2024, 6, 15, 10, 30),
        );

        final updatedState = CaptureState(
          memoryType: MemoryType.moment,
          existingPhotoUrls: ['file:///existing/photo1.jpg'],
          photoPaths: ['/new/photo2.jpg'],
        );

        final updated = original.copyWithFromCaptureState(
          state: updatedState,
        );

        expect(updated.photoPaths, contains('/existing/photo1.jpg'));
        expect(updated.photoPaths, contains('/new/photo2.jpg'));
        expect(updated.photoPaths.length, equals(2));
      });

      test('removes deleted photos', () {
        final original = QueuedMoment(
          localId: 'local-123',
          memoryType: 'moment',
          photoPaths: ['/photo1.jpg', '/photo2.jpg'],
          createdAt: DateTime(2024, 6, 15, 10, 30),
        );

        final updatedState = CaptureState(
          memoryType: MemoryType.moment,
          existingPhotoUrls: ['file:///photo1.jpg', 'file:///photo2.jpg'],
          deletedPhotoUrls: ['file:///photo1.jpg'], // Mark photo1 for deletion
          photoPaths: ['/photo3.jpg'], // Add new photo
        );

        final updated = original.copyWithFromCaptureState(
          state: updatedState,
        );

        expect(updated.photoPaths, isNot(contains('/photo1.jpg')));
        expect(updated.photoPaths, contains('/photo2.jpg')); // Preserved
        expect(updated.photoPaths, contains('/photo3.jpg')); // New
        expect(updated.photoPaths.length, equals(2));
      });

      test('updates location, preserves sync metadata', () {
        final original = QueuedMoment(
          localId: 'local-123',
          memoryType: 'moment',
          latitude: 40.7128,
          longitude: -74.0060,
          locationStatus: 'granted',
          status: 'syncing',
          retryCount: 1,
          createdAt: DateTime(2024, 6, 15, 10, 30),
          serverMomentId: 'server-123',
        );

        final updatedState = CaptureState(
          memoryType: MemoryType.moment,
          latitude: 37.7749,
          longitude: -122.4194,
          locationStatus: 'granted',
        );

        final updated = original.copyWithFromCaptureState(
          state: updatedState,
        );

        expect(updated.latitude, equals(37.7749));
        expect(updated.longitude, equals(-122.4194));
        expect(updated.status, equals('syncing')); // Preserved
        expect(updated.retryCount, equals(1)); // Preserved
        expect(updated.serverMomentId, equals('server-123')); // Preserved
      });
    });

    group('QueuedStory.copyWithFromCaptureState', () {
      test('updates text and tags, preserves audio metadata', () {
        final original = QueuedStory(
          localId: 'story-123',
          memoryType: 'story',
          inputText: 'Original story text',
          audioPath: '/path/to/audio.m4a',
          audioDuration: 120.5,
          tags: ['old-tag'],
          createdAt: DateTime(2024, 6, 15, 10, 30),
        );

        final updatedState = CaptureState(
          memoryType: MemoryType.story,
          inputText: 'Updated story text',
          tags: ['new-tag'],
        );

        final updated = original.copyWithFromCaptureState(
          state: updatedState,
        );

        expect(updated.inputText, equals('Updated story text'));
        expect(updated.tags, equals(['new-tag']));
        expect(updated.audioPath, equals('/path/to/audio.m4a')); // Preserved
        expect(updated.audioDuration, equals(120.5)); // Preserved
      });

      test('preserves sync metadata', () {
        final original = QueuedStory(
          localId: 'story-123',
          memoryType: 'story',
          status: 'syncing',
          retryCount: 3,
          createdAt: DateTime(2024, 6, 15, 10, 30),
          serverStoryId: 'server-story-123',
        );

        final updatedState = CaptureState(
          memoryType: MemoryType.story,
          inputText: 'Updated text',
        );

        final updated = original.copyWithFromCaptureState(
          state: updatedState,
        );

        expect(updated.status, equals('syncing')); // Preserved
        expect(updated.retryCount, equals(3)); // Preserved
        expect(updated.serverStoryId, equals('server-story-123')); // Preserved
      });
    });

    group('Queue Service Update Operations', () {
      test('updates queued moment in storage', () async {
        final original = QueuedMoment(
          localId: 'local-123',
          memoryType: 'moment',
          inputText: 'Original text',
          tags: ['tag1'],
          createdAt: DateTime(2024, 6, 15, 10, 30),
        );

        await queueService.enqueue(original);

        final updatedState = CaptureState(
          memoryType: MemoryType.moment,
          inputText: 'Updated text',
          tags: ['tag1', 'tag2'],
        );

        final updated = original.copyWithFromCaptureState(
          state: updatedState,
        );

        await queueService.update(updated);

        final retrieved = await queueService.getByLocalId('local-123');
        expect(retrieved, isNotNull);
        expect(retrieved!.inputText, equals('Updated text'));
        expect(retrieved.tags, equals(['tag1', 'tag2']));
        expect(retrieved.createdAt, equals(DateTime(2024, 6, 15, 10, 30))); // Preserved
      });

      test('updates queued story in storage', () async {
        final original = QueuedStory(
          localId: 'story-123',
          memoryType: 'story',
          inputText: 'Original story',
          audioPath: '/audio.m4a',
          createdAt: DateTime(2024, 6, 15, 10, 30),
        );

        await storyQueueService.enqueue(original);

        final updatedState = CaptureState(
          memoryType: MemoryType.story,
          inputText: 'Updated story',
        );

        final updated = original.copyWithFromCaptureState(
          state: updatedState,
        );

        await storyQueueService.update(updated);

        final retrieved = await storyQueueService.getByLocalId('story-123');
        expect(retrieved, isNotNull);
        expect(retrieved!.inputText, equals('Updated story'));
        expect(retrieved.audioPath, equals('/audio.m4a')); // Preserved
        expect(retrieved.createdAt, equals(DateTime(2024, 6, 15, 10, 30))); // Preserved
      });

      test('update preserves sync status across app restarts', () async {
        final original = QueuedMoment(
          localId: 'local-123',
          memoryType: 'moment',
          inputText: 'Original',
          status: 'syncing',
          retryCount: 2,
          createdAt: DateTime(2024, 6, 15, 10, 30),
        );

        await queueService.enqueue(original);

        // Simulate edit
        final updatedState = CaptureState(
          memoryType: MemoryType.moment,
          inputText: 'Updated',
        );

        final updated = original.copyWithFromCaptureState(
          state: updatedState,
          status: 'syncing', // Explicitly preserve
          retryCount: 2,
        );

        await queueService.update(updated);

        // Create new service instance to simulate app restart
        final newService = OfflineQueueService();
        final retrieved = await newService.getByLocalId('local-123');
        expect(retrieved, isNotNull);
        expect(retrieved!.status, equals('syncing')); // Preserved
        expect(retrieved.retryCount, equals(2)); // Preserved
        expect(retrieved.inputText, equals('Updated')); // Updated
      });
    });
  });
}

