import 'dart:async';
import 'package:memories/models/memory_type.dart';
import 'package:memories/services/connectivity_service.dart';
import 'package:memories/services/memory_save_service.dart';
import 'package:memories/services/offline_queue_service.dart';
import 'package:memories/services/offline_story_queue_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'memory_sync_service.g.dart';

/// Event emitted when a queued memory successfully syncs to the server
class SyncCompleteEvent {
  final String localId;
  final String serverId;
  final MemoryType memoryType;

  SyncCompleteEvent({
    required this.localId,
    required this.serverId,
    required this.memoryType,
  });
}

/// Service for syncing queued memories (moments, mementos, and stories) to the server
/// 
/// Handles automatic retry with exponential backoff for all memory types
/// stored in the offline queues (moments/mementos and stories).
@riverpod
MemorySyncService memorySyncService(MemorySyncServiceRef ref) {
  final queueService = ref.watch(offlineQueueServiceProvider);
  final storyQueueService = ref.watch(offlineStoryQueueServiceProvider);
  final connectivityService = ref.watch(connectivityServiceProvider);
  final saveService = ref.watch(memorySaveServiceProvider);
  
  return MemorySyncService(
    queueService,
    storyQueueService,
    connectivityService,
    saveService,
  );
}

class MemorySyncService {
  final OfflineQueueService _queueService;
  final OfflineStoryQueueService _storyQueueService;
  final ConnectivityService _connectivityService;
  final MemorySaveService _saveService;
  
  Timer? _syncTimer;
  StreamSubscription<bool>? _connectivitySubscription;
  bool _isSyncing = false;
  final _syncCompleteController = StreamController<SyncCompleteEvent>.broadcast();

  MemorySyncService(
    this._queueService,
    this._storyQueueService,
    this._connectivityService,
    this._saveService,
  );

  /// Stream of sync completion events
  Stream<SyncCompleteEvent> get syncCompleteStream =>
      _syncCompleteController.stream;

  /// Start automatic sync when connectivity is restored
  void startAutoSync() {
    // Listen for connectivity changes
    _connectivitySubscription = _connectivityService.connectivityStream.listen(
      (isOnline) {
        if (isOnline && !_isSyncing) {
          syncQueuedMemories();
        }
      },
    );

    // Also sync periodically (every 30 seconds) when online
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!_isSyncing) {
        _connectivityService.isOnline().then((isOnline) {
          if (isOnline) {
            syncQueuedMemories();
          }
        });
      }
    });
  }

  /// Stop automatic sync
  void stopAutoSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
  }

  /// Dispose resources
  void dispose() {
    stopAutoSync();
    _syncCompleteController.close();
  }

  /// Manually trigger sync of all queued memories (moments, mementos, and stories)
  Future<void> syncQueuedMemories() async {
    if (_isSyncing) return;
    
    final isOnline = await _connectivityService.isOnline();
    if (!isOnline) return;

    _isSyncing = true;
    
    try {
      // Sync moments and mementos
      await _syncMomentsAndMementos();
      
      // Sync stories
      await _syncStories();
    } finally {
      _isSyncing = false;
    }
  }

  /// Sync moments and mementos from the main queue
  Future<void> _syncMomentsAndMementos() async {
    // Get all queued items (moments and mementos)
    final queued = await _queueService.getByStatus('queued');
    final failed = await _queueService.getByStatus('failed');

    // Process queued items first, then retry failed ones
    final memoriesToSync = [...queued, ...failed];

    for (final queuedMemory in memoriesToSync) {
      try {
        // Update status to syncing
        await _queueService.update(
          queuedMemory.copyWith(
            status: 'syncing',
            lastRetryAt: DateTime.now(),
          ),
        );

        // Convert to CaptureState and save
        final state = queuedMemory.toCaptureState();
        final result = await _saveService.saveMoment(state: state);

        // Mark as completed and remove from queue
        await _queueService.update(
          queuedMemory.copyWith(
            status: 'completed',
            serverMomentId: result.memoryId,
          ),
        );

        // Emit sync completion event
        final memoryType = MemoryTypeExtension.fromApiValue(queuedMemory.memoryType);
        _syncCompleteController.add(
          SyncCompleteEvent(
            localId: queuedMemory.localId,
            serverId: result.memoryId,
            memoryType: memoryType,
          ),
        );

        // Remove from queue after successful sync
        await _queueService.remove(queuedMemory.localId);
      } catch (e) {
        // Update retry count and mark as failed if max retries reached
        final newRetryCount = queuedMemory.retryCount + 1;
        final maxRetries = 3;

        if (newRetryCount >= maxRetries) {
          await _queueService.update(
            queuedMemory.copyWith(
              status: 'failed',
              retryCount: newRetryCount,
              errorMessage: e.toString(),
              lastRetryAt: DateTime.now(),
            ),
          );
        } else {
          // Retry later with exponential backoff
          await _queueService.update(
            queuedMemory.copyWith(
              status: 'queued',
              retryCount: newRetryCount,
              errorMessage: e.toString(),
              lastRetryAt: DateTime.now(),
            ),
          );
        }
      }
    }
  }

  /// Sync stories from the story queue
  Future<void> _syncStories() async {
    // Get all queued stories
    final queued = await _storyQueueService.getByStatus('queued');
    final failed = await _storyQueueService.getByStatus('failed');

    // Process queued items first, then retry failed ones
    final storiesToSync = [...queued, ...failed];

    for (final queuedStory in storiesToSync) {
      try {
        // Update status to syncing
        await _storyQueueService.update(
          queuedStory.copyWith(
            status: 'syncing',
            lastRetryAt: DateTime.now(),
          ),
        );

        // Convert to CaptureState and save (includes audioPath and audioDuration)
        final state = queuedStory.toCaptureState();
        final result = await _saveService.saveMoment(state: state);

        // Mark as completed and remove from queue
        await _storyQueueService.update(
          queuedStory.copyWith(
            status: 'completed',
            serverStoryId: result.memoryId,
          ),
        );

        // Emit sync completion event
        final memoryType = MemoryTypeExtension.fromApiValue(queuedStory.memoryType);
        _syncCompleteController.add(
          SyncCompleteEvent(
            localId: queuedStory.localId,
            serverId: result.memoryId,
            memoryType: memoryType,
          ),
        );

        // Remove from queue after successful sync
        await _storyQueueService.remove(queuedStory.localId);
      } catch (e) {
        // Update retry count and mark as failed if max retries reached
        final newRetryCount = queuedStory.retryCount + 1;
        final maxRetries = 3;

        if (newRetryCount >= maxRetries) {
          await _storyQueueService.update(
            queuedStory.copyWith(
              status: 'failed',
              retryCount: newRetryCount,
              errorMessage: e.toString(),
              lastRetryAt: DateTime.now(),
            ),
          );
        } else {
          // Retry later with exponential backoff
          await _storyQueueService.update(
            queuedStory.copyWith(
              status: 'queued',
              retryCount: newRetryCount,
              errorMessage: e.toString(),
              lastRetryAt: DateTime.now(),
            ),
          );
        }
      }
    }
  }

  /// Sync a specific queued memory by local ID
  /// 
  /// Tries both the moment queue and story queue to find the memory.
  Future<void> syncMemory(String localId) async {
    final isOnline = await _connectivityService.isOnline();
    if (!isOnline) {
      throw Exception('Device is offline');
    }

    // Try moment queue first
    final queuedMemory = await _queueService.getByLocalId(localId);
    if (queuedMemory != null) {
      try {
        await _queueService.update(
          queuedMemory.copyWith(
            status: 'syncing',
            lastRetryAt: DateTime.now(),
          ),
        );

        final state = queuedMemory.toCaptureState();
        final result = await _saveService.saveMoment(state: state);

        await _queueService.update(
          queuedMemory.copyWith(
            status: 'completed',
            serverMomentId: result.memoryId,
          ),
        );

        // Emit sync completion event
        final memoryType = MemoryTypeExtension.fromApiValue(queuedMemory.memoryType);
        _syncCompleteController.add(
          SyncCompleteEvent(
            localId: queuedMemory.localId,
            serverId: result.memoryId,
            memoryType: memoryType,
          ),
        );

        await _queueService.remove(queuedMemory.localId);
        return;
      } catch (e) {
        final newRetryCount = queuedMemory.retryCount + 1;
        await _queueService.update(
          queuedMemory.copyWith(
            status: newRetryCount >= 3 ? 'failed' : 'queued',
            retryCount: newRetryCount,
            errorMessage: e.toString(),
            lastRetryAt: DateTime.now(),
          ),
        );
        rethrow;
      }
    }

    // Try story queue
    final queuedStory = await _storyQueueService.getByLocalId(localId);
    if (queuedStory != null) {
      try {
        await _storyQueueService.update(
          queuedStory.copyWith(
            status: 'syncing',
            lastRetryAt: DateTime.now(),
          ),
        );

        final state = queuedStory.toCaptureState();
        final result = await _saveService.saveMoment(state: state);

        await _storyQueueService.update(
          queuedStory.copyWith(
            status: 'completed',
            serverStoryId: result.memoryId,
          ),
        );

        // Emit sync completion event
        final memoryType = MemoryTypeExtension.fromApiValue(queuedStory.memoryType);
        _syncCompleteController.add(
          SyncCompleteEvent(
            localId: queuedStory.localId,
            serverId: result.memoryId,
            memoryType: memoryType,
          ),
        );

        await _storyQueueService.remove(queuedStory.localId);
        return;
      } catch (e) {
        final newRetryCount = queuedStory.retryCount + 1;
        await _storyQueueService.update(
          queuedStory.copyWith(
            status: newRetryCount >= 3 ? 'failed' : 'queued',
            retryCount: newRetryCount,
            errorMessage: e.toString(),
            lastRetryAt: DateTime.now(),
          ),
        );
        rethrow;
      }
    }

    // Not found in either queue
    throw Exception('Memory not found in queue: $localId');
  }
}

