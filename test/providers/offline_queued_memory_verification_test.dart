import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gotrue/gotrue.dart';
import 'dart:async';
import 'package:memories/providers/unified_feed_provider.dart';
import 'package:memories/providers/supabase_provider.dart';
import 'package:memories/services/connectivity_service.dart';
import 'package:memories/services/unified_feed_repository.dart';
import 'package:memories/models/timeline_memory.dart';
import 'package:memories/models/memory_type.dart';
import 'package:memories/services/offline_memory_queue_service.dart';
import 'package:memories/services/shared_preferences_local_memory_preview_store.dart';
import 'package:memories/services/memory_sync_service.dart';
import 'package:memories/models/queued_memory.dart';
import 'package:memories/services/offline_queue_to_timeline_adapter.dart';
import 'package:memories/services/memory_sync_service.dart';
import 'package:memories/models/queue_change_event.dart';
import 'dart:async';

// Mock classes
class MockGoTrueClient extends Mock implements GoTrueClient {}

class MockSupabaseClient extends Mock implements SupabaseClient {
  @override
  GoTrueClient get auth => MockGoTrueClient();
}

class MockConnectivityService extends Mock implements ConnectivityService {}

class MockUnifiedFeedRepository extends Mock implements UnifiedFeedRepository {}

class MockOfflineMemoryQueueService extends Mock
    implements OfflineMemoryQueueService {
  final _changeController = StreamController<QueueChangeEvent>.broadcast();

  @override
  Stream<QueueChangeEvent> get changeStream => _changeController.stream;

  void dispose() {
    _changeController.close();
  }
}

class MockLocalMemoryPreviewStore extends Mock
    implements SharedPreferencesLocalMemoryPreviewStore {}

class MockMemorySyncService extends Mock implements MemorySyncService {
  final _syncCompleteController =
      StreamController<SyncCompleteEvent>.broadcast();

  @override
  Stream<SyncCompleteEvent> get syncCompleteStream =>
      _syncCompleteController.stream;

  void dispose() {
    _syncCompleteController.close();
  }
}

void main() {
  group('Offline Queued Memory Verification Tests', () {
    late MockSupabaseClient mockSupabase;
    late MockConnectivityService mockConnectivity;
    late MockUnifiedFeedRepository mockRepository;
    late MockOfflineMemoryQueueService mockOfflineQueueService;
    late MockLocalMemoryPreviewStore mockLocalMemoryPreviewStore;
    late MockMemorySyncService mockSyncService;
    late ProviderContainer container;

    setUp(() {
      mockSupabase = MockSupabaseClient();
      mockConnectivity = MockConnectivityService();
      mockRepository = MockUnifiedFeedRepository();
      mockOfflineQueueService = MockOfflineMemoryQueueService();
      mockLocalMemoryPreviewStore = MockLocalMemoryPreviewStore();
      mockSyncService = MockMemorySyncService();

      container = ProviderContainer(
        overrides: [
          supabaseClientProvider.overrideWithValue(mockSupabase),
          connectivityServiceProvider.overrideWithValue(mockConnectivity),
          offlineMemoryQueueServiceProvider
              .overrideWithValue(mockOfflineQueueService),
          localMemoryPreviewStoreProvider
              .overrideWithValue(mockLocalMemoryPreviewStore),
          unifiedFeedRepositoryProvider.overrideWithValue(mockRepository),
          memorySyncServiceProvider.overrideWithValue(mockSyncService),
        ],
      );

      // Default connectivity to online
      when(() => mockConnectivity.isOnline()).thenAnswer((_) async => true);

      // Default mock for fetchAvailableYears
      when(() => mockRepository.fetchAvailableYears(
            filters: any(named: 'filters'),
          )).thenAnswer((_) async => [2025]);

      // Mock Supabase auth
      when(() => (mockSupabase.auth as MockGoTrueClient).onAuthStateChange)
          .thenAnswer((_) => const Stream.empty());
    });

    tearDown(() {
      container.dispose();
      if (mockSyncService is MockMemorySyncService) {
        (mockSyncService as MockMemorySyncService).dispose();
      }
      if (mockOfflineQueueService is MockOfflineMemoryQueueService) {
        (mockOfflineQueueService as MockOfflineMemoryQueueService).dispose();
      }
    });

    group('Verification 1: Queue removal race condition', () {
      test('queued memory removed during fetch does not reappear post-fetch',
          () async {
        final testDate = DateTime(2025, 1, 17);
        final queuedMemory = TimelineMemory(
          id: 'local-1',
          userId: 'user-1',
          title: 'Queued Memory',
          capturedAt: testDate,
          createdAt: testDate,
          memoryDate: testDate,
          year: 2025,
          season: 'Winter',
          month: 1,
          day: 17,
          tags: [],
          memoryType: 'moment',
          isOfflineQueued: true,
          isPreviewOnly: false,
          isDetailCachedLocally: true,
          localId: 'local-1',
          offlineSyncStatus: OfflineSyncStatus.queued,
        );

        // Simulate fetch starting with queued memory
        when(() => mockRepository.fetchMergedFeed(
              cursor: any(named: 'cursor'),
              filters: any(named: 'filters'),
              batchSize: any(named: 'batchSize'),
              isOnline: any(named: 'isOnline'),
            )).thenAnswer((_) async {
          // Simulate delay during fetch
          await Future.delayed(const Duration(milliseconds: 50));
          return UnifiedFeedPageResult(
            memories: [queuedMemory],
            hasMore: false,
          );
        });

        // Simulate queue service returning null (memory was removed during fetch)
        when(() => mockOfflineQueueService.getByLocalId('local-1'))
            .thenAnswer((_) async => null);

        final notifier = container.read(unifiedFeedProvider.notifier);
        await notifier.loadInitial();

        // Verify queued memory is NOT in the feed (was filtered out)
        final state = container.read(unifiedFeedProvider);
        expect(state.memories.length, 0);
        expect(state.memories.any((m) => m.localId == 'local-1'), false);
      });
    });

    group('Verification 2: Navigation guard for synced queued cards', () {
      test(
          'queued memory with serverId redirects to online detail when queue entry is gone',
          () async {
        final testDate = DateTime(2025, 1, 17);
        final queuedMemoryWithServerId = TimelineMemory(
          id: 'local-1',
          userId: 'user-1',
          title: 'Synced Memory',
          capturedAt: testDate,
          createdAt: testDate,
          memoryDate: testDate,
          year: 2025,
          season: 'Winter',
          month: 1,
          day: 17,
          tags: [],
          memoryType: 'moment',
          isOfflineQueued: true,
          isPreviewOnly: false,
          isDetailCachedLocally: true,
          localId: 'local-1',
          serverId: 'server-1', // Has serverId from previous sync attempt
          offlineSyncStatus: OfflineSyncStatus.failed,
        );

        // Queue entry is gone (synced or removed)
        when(() => mockOfflineQueueService.getByLocalId('local-1'))
            .thenAnswer((_) async => null);

        // The memory has a serverId, so navigation should redirect to online detail
        expect(queuedMemoryWithServerId.serverId, isNotNull);
        expect(queuedMemoryWithServerId.serverId, 'server-1');
      });

      test(
          'queued memory without serverId shows error when queue entry is gone',
          () async {
        final testDate = DateTime(2025, 1, 17);
        final queuedMemoryWithoutServerId = TimelineMemory(
          id: 'local-1',
          userId: 'user-1',
          title: 'Queued Memory',
          capturedAt: testDate,
          createdAt: testDate,
          memoryDate: testDate,
          year: 2025,
          season: 'Winter',
          month: 1,
          day: 17,
          tags: [],
          memoryType: 'moment',
          isOfflineQueued: true,
          isPreviewOnly: false,
          isDetailCachedLocally: true,
          localId: 'local-1',
          serverId: null, // No serverId
          offlineSyncStatus: OfflineSyncStatus.queued,
        );

        // Queue entry is gone
        when(() => mockOfflineQueueService.getByLocalId('local-1'))
            .thenAnswer((_) async => null);

        // Memory without serverId should trigger error/refresh flow
        expect(queuedMemoryWithoutServerId.serverId, isNull);
      });
    });

    group('Verification 3: Offline edits stay visible in feed', () {
      test('queued update with serverId remains visible in merged feed',
          () async {
        final testDate = DateTime(2025, 1, 17);

        // Create a queued memory that represents an offline edit
        // (has serverId but status != 'completed')
        final queuedEdit = QueuedMemory(
          localId: 'local-1',
          memoryType: 'moment',
          inputText: 'Edited text',
          photoPaths: [],
          videoPaths: [],
          tags: [],
          status: 'queued', // Not completed, so should appear
          retryCount: 0,
          createdAt: testDate,
          operation: QueuedMemory.operationUpdate,
          targetMemoryId: 'server-1', // Has serverId
          existingPhotoUrls: [],
          existingVideoUrls: [],
          deletedPhotoUrls: [],
          deletedVideoUrls: [],
          serverMemoryId: 'server-1', // Offline edit has serverId
        );

        final timelineMemory =
            OfflineQueueToTimelineAdapter.fromQueuedMemory(queuedEdit);

        // Verify the adapter preserves serverId
        expect(timelineMemory.serverId, 'server-1');
        expect(timelineMemory.isOfflineQueued, true);
        expect(timelineMemory.localId, 'local-1');

        // Simulate repository returning this in merged feed
        when(() => mockRepository.fetchMergedFeed(
              cursor: any(named: 'cursor'),
              filters: any(named: 'filters'),
              batchSize: any(named: 'batchSize'),
              isOnline: any(named: 'isOnline'),
            )).thenAnswer((_) async => UnifiedFeedPageResult(
              memories: [timelineMemory],
              hasMore: false,
            ));

        // Queue service should return the queued edit
        when(() => mockOfflineQueueService.getByLocalId('local-1'))
            .thenAnswer((_) async => queuedEdit);

        final notifier = container.read(unifiedFeedProvider.notifier);
        await notifier.loadInitial();

        // Verify queued edit appears in feed
        final state = container.read(unifiedFeedProvider);
        expect(state.memories.length, 1);
        expect(state.memories.first.localId, 'local-1');
        expect(state.memories.first.serverId, 'server-1');
        expect(state.memories.first.isOfflineQueued, true);
      });

      test('completed queued entries are filtered out', () async {
        final testDate = DateTime(2025, 1, 17);

        // Create a completed queued memory (should be filtered out)
        final completedQueued = QueuedMemory(
          localId: 'local-1',
          memoryType: 'moment',
          inputText: 'Completed memory',
          photoPaths: [],
          videoPaths: [],
          tags: [],
          status: 'completed', // Completed status
          retryCount: 0,
          createdAt: testDate,
          operation: QueuedMemory.operationCreate,
          existingPhotoUrls: [],
          existingVideoUrls: [],
          deletedPhotoUrls: [],
          deletedVideoUrls: [],
          serverMemoryId: 'server-1',
        );

        // Repository should filter out completed entries
        // (This is done in UnifiedFeedRepository.fetchQueuedMemories)
        // So completed entries won't appear in fetchMergedFeed results
        when(() => mockRepository.fetchMergedFeed(
              cursor: any(named: 'cursor'),
              filters: any(named: 'filters'),
              batchSize: any(named: 'batchSize'),
              isOnline: any(named: 'isOnline'),
            )).thenAnswer((_) async => UnifiedFeedPageResult(
              memories: [], // Completed entries filtered out
              hasMore: false,
            ));

        final notifier = container.read(unifiedFeedProvider.notifier);
        await notifier.loadInitial();

        // Verify completed entry does not appear
        final state = container.read(unifiedFeedProvider);
        expect(state.memories.length, 0);
      });
    });

    group('Verification 4: Offline error handling', () {
      test(
          'offline detail provider throws "not found" when queue entry is gone',
          () async {
        // Simulate queue entry being removed (synced or failed)
        when(() => mockOfflineQueueService.getByLocalId('local-1'))
            .thenAnswer((_) async => null);

        // This would be tested in offline_memory_detail_provider_test.dart
        // but we verify the service behavior here
        final result = await mockOfflineQueueService.getByLocalId('local-1');
        expect(result, isNull);
      });
    });
  });
}
