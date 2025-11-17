import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:memories/models/capture_state.dart';
import 'package:memories/models/memory_type.dart';
import 'package:memories/services/dictation_service.dart';
import 'package:memories/services/geolocation_service.dart';

part 'capture_state_provider.g.dart';

/// Provider for dictation service
@riverpod
DictationService dictationService(DictationServiceRef ref) {
  final service = DictationService();
  ref.onDispose(() => service.dispose());
  return service;
}

/// Provider for geolocation service
@riverpod
GeolocationService geolocationService(GeolocationServiceRef ref) {
  return GeolocationService();
}

/// Provider for capture state
/// 
/// Manages the state of the unified capture sheet including:
/// - Memory type selection (Moment/Story/Memento)
/// - Dictation transcript
/// - Description text
/// - Media attachments (photos/videos)
/// - Tags
/// - Dictation status
@riverpod
class CaptureStateNotifier extends _$CaptureStateNotifier {
  @override
  CaptureState build() {
    return const CaptureState();
  }

  /// Set memory type
  void setMemoryType(MemoryType type) {
    state = state.copyWith(
      memoryType: type,
      hasUnsavedChanges: true,
    );
  }

  /// Start dictation
  Future<void> startDictation() async {
    final dictationService = ref.read(dictationServiceProvider);
    
    if (state.isDictating) {
      return;
    }

    final started = await dictationService.start();
    if (!started) {
      state = state.copyWith(
        errorMessage: 'Failed to start dictation',
      );
      return;
    }

    // Listen to transcript updates
    dictationService.transcriptStream.listen((transcript) {
      state = state.copyWith(
        rawTranscript: transcript,
        hasUnsavedChanges: true,
      );
    });

    state = state.copyWith(
      isDictating: true,
      captureStartTime: state.captureStartTime ?? DateTime.now(),
      hasUnsavedChanges: true,
    );
  }

  /// Stop dictation
  Future<void> stopDictation() async {
    if (!state.isDictating) {
      return;
    }

    final dictationService = ref.read(dictationServiceProvider);
    final finalTranscript = await dictationService.stop();

    state = state.copyWith(
      isDictating: false,
      rawTranscript: finalTranscript.isNotEmpty ? finalTranscript : state.rawTranscript,
      hasUnsavedChanges: true,
    );
  }

  /// Update description text
  void updateDescription(String? description) {
    state = state.copyWith(
      description: description,
      hasUnsavedChanges: true,
    );
  }

  /// Add photo path
  void addPhoto(String path) {
    if (!state.canAddPhoto) {
      return;
    }

    final updatedPhotos = [...state.photoPaths, path];
    state = state.copyWith(
      photoPaths: updatedPhotos,
      hasUnsavedChanges: true,
    );
  }

  /// Remove photo at index
  void removePhoto(int index) {
    if (index < 0 || index >= state.photoPaths.length) {
      return;
    }

    final updatedPhotos = List<String>.from(state.photoPaths);
    updatedPhotos.removeAt(index);
    state = state.copyWith(
      photoPaths: updatedPhotos,
      hasUnsavedChanges: true,
    );
  }

  /// Add video path
  void addVideo(String path) {
    if (!state.canAddVideo) {
      return;
    }

    final updatedVideos = [...state.videoPaths, path];
    state = state.copyWith(
      videoPaths: updatedVideos,
      hasUnsavedChanges: true,
    );
  }

  /// Remove video at index
  void removeVideo(int index) {
    if (index < 0 || index >= state.videoPaths.length) {
      return;
    }

    final updatedVideos = List<String>.from(state.videoPaths);
    updatedVideos.removeAt(index);
    state = state.copyWith(
      videoPaths: updatedVideos,
      hasUnsavedChanges: true,
    );
  }

  /// Add tag
  void addTag(String tag) {
    final trimmedTag = tag.trim().toLowerCase();
    if (trimmedTag.isEmpty) {
      return;
    }

    // Check if tag already exists (case-insensitive)
    if (state.tags.any((t) => t.toLowerCase() == trimmedTag)) {
      return;
    }

    final updatedTags = [...state.tags, trimmedTag];
    state = state.copyWith(
      tags: updatedTags,
      hasUnsavedChanges: true,
    );
  }

  /// Remove tag at index
  void removeTag(int index) {
    if (index < 0 || index >= state.tags.length) {
      return;
    }

    final updatedTags = List<String>.from(state.tags);
    updatedTags.removeAt(index);
    state = state.copyWith(
      tags: updatedTags,
      hasUnsavedChanges: true,
    );
  }

  /// Clear all state
  void clear() {
    final dictationService = ref.read(dictationServiceProvider);
    if (state.isDictating) {
      dictationService.stop();
    }
    dictationService.clear();

    state = const CaptureState();
  }

  /// Set error message
  void setError(String? error) {
    state = state.copyWith(errorMessage: error);
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  /// Capture location metadata
  /// 
  /// Attempts to get current position and updates state with location
  /// or location status (denied/unavailable)
  Future<void> captureLocation() async {
    final geolocationService = ref.read(geolocationServiceProvider);
    
    try {
      final position = await geolocationService.getCurrentPosition();
      final status = await geolocationService.getLocationStatus();
      
      if (position != null) {
        state = state.copyWith(
          latitude: position.latitude,
          longitude: position.longitude,
          locationStatus: status,
        );
      } else {
        state = state.copyWith(
          locationStatus: status,
        );
      }
    } catch (e) {
      // On error, mark as unavailable
      state = state.copyWith(
        locationStatus: 'unavailable',
      );
    }
  }

  /// Set captured timestamp
  void setCapturedAt(DateTime timestamp) {
    state = state.copyWith(capturedAt: timestamp);
  }
}

