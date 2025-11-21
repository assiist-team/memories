import 'dart:io';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:memories/models/memory_detail.dart';
import 'package:memories/models/queued_moment.dart';
import 'package:memories/models/queued_story.dart';
import 'package:memories/services/offline_queue_service.dart';
import 'package:memories/services/offline_story_queue_service.dart';

part 'offline_memory_detail_provider.g.dart';

/// Provider for offline memory detail (queued items only)
///
/// [localId] is the local ID of the queued memory to fetch
/// This provider only works for queued offline memories stored in local queues.
/// It does not attempt to fetch remote details for preview-only entries.
@riverpod
class OfflineMemoryDetailNotifier extends _$OfflineMemoryDetailNotifier {
  @override
  Future<MemoryDetail> build(String localId) async {
    final queueService = ref.read(offlineQueueServiceProvider);
    final storyQueueService = ref.read(offlineStoryQueueServiceProvider);

    // Try to find in main queue (moments/mementos)
    final queuedMoment = await queueService.getByLocalId(localId);
    if (queuedMoment != null) {
      return _toDetailFromQueuedMoment(queuedMoment);
    }

    // Try to find in story queue
    final queuedStory = await storyQueueService.getByLocalId(localId);
    if (queuedStory != null) {
      return _toDetailFromQueuedStory(queuedStory);
    }

    throw Exception('Offline queued memory not found: $localId');
  }

  /// Convert a QueuedMoment to MemoryDetail
  MemoryDetail _toDetailFromQueuedMoment(QueuedMoment queued) {
    final capturedAt = queued.capturedAt ?? queued.createdAt;

    // Convert photo paths to PhotoMedia
    final photos = queued.photoPaths.asMap().entries
        .where((entry) {
          // Filter out entries whose file no longer exists
          final path = entry.value.replaceFirst('file://', '');
          return File(path).existsSync();
        })
        .map((entry) {
          // Normalize path to file:// form for clarity
          final path = entry.value.replaceFirst('file://', '');
          final normalizedPath = path.startsWith('/') ? 'file://$path' : 'file:///$path';
          return PhotoMedia(
            url: normalizedPath,
            index: entry.key,
            caption: null,
            source: MediaSource.localFile,
          );
        })
        .toList();

    // Convert video paths to VideoMedia
    final videos = queued.videoPaths.asMap().entries
        .where((entry) {
          // Filter out entries whose file no longer exists
          final path = entry.value.replaceFirst('file://', '');
          return File(path).existsSync();
        })
        .map((entry) {
          // Normalize path to file:// form for clarity
          final path = entry.value.replaceFirst('file://', '');
          final normalizedPath = path.startsWith('/') ? 'file://$path' : 'file:///$path';
          return VideoMedia(
            url: normalizedPath,
            index: entry.key,
            duration: null,
            posterUrl: null,
            caption: null,
            source: MediaSource.localFile,
          );
        })
        .toList();

    // Create location data if available
    LocationData? locationData;
    if (queued.latitude != null && queued.longitude != null) {
      locationData = LocationData(
        latitude: queued.latitude,
        longitude: queued.longitude,
        status: queued.locationStatus,
        city: null, // Not available for queued items
        state: null, // Not available for queued items
      );
    }

    // Generate title from input text if needed
    final title = _generateTitleFromInputText(queued.inputText, queued.memoryType);

    return MemoryDetail(
      id: queued.localId,
      userId: '', // Not available for queued items until sync
      title: title,
      inputText: queued.inputText,
      processedText: null, // Not available for queued items (LLM hasn't run)
      generatedTitle: null, // Not available for queued items
      tags: List.from(queued.tags),
      memoryType: queued.memoryType,
      capturedAt: capturedAt,
      createdAt: queued.createdAt,
      updatedAt: queued.createdAt, // Use createdAt as updatedAt for queued items
      publicShareToken: null, // Not available for queued items
      locationData: locationData,
      photos: photos,
      videos: videos,
      relatedStories: [], // Not available for queued items
      relatedMementos: [], // Not available for queued items
    );
  }

  /// Convert a QueuedStory to MemoryDetail
  MemoryDetail _toDetailFromQueuedStory(QueuedStory queued) {
    final capturedAt = queued.capturedAt ?? queued.createdAt;

    // Convert photo paths to PhotoMedia
    final photos = queued.photoPaths.asMap().entries
        .where((entry) {
          // Filter out entries whose file no longer exists
          final path = entry.value.replaceFirst('file://', '');
          return File(path).existsSync();
        })
        .map((entry) {
          // Normalize path to file:// form for clarity
          final path = entry.value.replaceFirst('file://', '');
          final normalizedPath = path.startsWith('/') ? 'file://$path' : 'file:///$path';
          return PhotoMedia(
            url: normalizedPath,
            index: entry.key,
            caption: null,
            source: MediaSource.localFile,
          );
        })
        .toList();

    // Convert video paths to VideoMedia
    final videos = queued.videoPaths.asMap().entries
        .where((entry) {
          // Filter out entries whose file no longer exists
          final path = entry.value.replaceFirst('file://', '');
          return File(path).existsSync();
        })
        .map((entry) {
          // Normalize path to file:// form for clarity
          final path = entry.value.replaceFirst('file://', '');
          final normalizedPath = path.startsWith('/') ? 'file://$path' : 'file:///$path';
          return VideoMedia(
            url: normalizedPath,
            index: entry.key,
            duration: null,
            posterUrl: null,
            caption: null,
            source: MediaSource.localFile,
          );
        })
        .toList();

    // For stories, audio is stored separately - we'll handle it in the UI layer
    // The audioPath is available in QueuedStory but not in MemoryDetail model
    // This is fine - the detail screen can access it from the queue if needed

    // Create location data if available
    LocationData? locationData;
    if (queued.latitude != null && queued.longitude != null) {
      locationData = LocationData(
        latitude: queued.latitude,
        longitude: queued.longitude,
        status: queued.locationStatus,
        city: null, // Not available for queued items
        state: null, // Not available for queued items
      );
    }

    // Generate title from input text if needed
    final title = _generateTitleFromInputText(queued.inputText, queued.memoryType);

    return MemoryDetail(
      id: queued.localId,
      userId: '', // Not available for queued items until sync
      title: title,
      inputText: queued.inputText,
      processedText: null, // Not available for queued items (LLM hasn't run)
      generatedTitle: null, // Not available for queued items
      tags: List.from(queued.tags),
      memoryType: queued.memoryType,
      capturedAt: capturedAt,
      createdAt: queued.createdAt,
      updatedAt: queued.createdAt, // Use createdAt as updatedAt for queued items
      publicShareToken: null, // Not available for queued items
      locationData: locationData,
      photos: photos,
      videos: videos,
      relatedStories: [], // Not available for queued items
      relatedMementos: [], // Not available for queued items
    );
  }

  /// Generate a title from input text
  /// Falls back to appropriate "Untitled" text based on memory type
  String _generateTitleFromInputText(String? inputText, String memoryType) {
    if (inputText != null && inputText.trim().isNotEmpty) {
      // Use first line or first 50 characters as title
      final lines = inputText.trim().split('\n');
      final firstLine = lines.first.trim();
      if (firstLine.isNotEmpty) {
        return firstLine.length > 50 ? '${firstLine.substring(0, 50)}...' : firstLine;
      }
    }

    // Fallback to appropriate "Untitled" text
    switch (memoryType.toLowerCase()) {
      case 'story':
        return 'Untitled Story';
      case 'memento':
        return 'Untitled Memento';
      case 'moment':
      default:
        return 'Untitled Moment';
    }
  }
}

