import 'package:memories/models/memory_type.dart';

/// Model representing the state of a memory being captured
class CaptureState {
  /// The type of memory being captured
  final MemoryType memoryType;
  
  /// Raw transcript from dictation
  final String? rawTranscript;
  
  /// Optional text description (editable)
  final String? description;
  
  /// List of selected photo file paths (local paths before upload)
  final List<String> photoPaths;
  
  /// List of selected video file paths (local paths before upload)
  final List<String> videoPaths;
  
  /// List of tags (case-insensitive, trimmed)
  final List<String> tags;
  
  /// Whether dictation is currently active
  final bool isDictating;
  
  /// Timestamp when capture started
  final DateTime? captureStartTime;
  
  /// Timestamp when capture was saved
  final DateTime? capturedAt;
  
  /// Location coordinates (latitude, longitude)
  final double? latitude;
  final double? longitude;
  
  /// Location status: 'granted', 'denied', or 'unavailable'
  final String? locationStatus;
  
  /// Whether there are unsaved changes
  final bool hasUnsavedChanges;
  
  /// Error message if any
  final String? errorMessage;

  const CaptureState({
    this.memoryType = MemoryType.moment,
    this.rawTranscript,
    this.description,
    this.photoPaths = const [],
    this.videoPaths = const [],
    this.tags = const [],
    this.isDictating = false,
    this.captureStartTime,
    this.capturedAt,
    this.latitude,
    this.longitude,
    this.locationStatus,
    this.hasUnsavedChanges = false,
    this.errorMessage,
  });

  /// Create a copy with updated fields
  CaptureState copyWith({
    MemoryType? memoryType,
    String? rawTranscript,
    String? description,
    List<String>? photoPaths,
    List<String>? videoPaths,
    List<String>? tags,
    bool? isDictating,
    DateTime? captureStartTime,
    DateTime? capturedAt,
    double? latitude,
    double? longitude,
    String? locationStatus,
    bool? hasUnsavedChanges,
    String? errorMessage,
    bool clearTranscript = false,
    bool clearDescription = false,
    bool clearError = false,
    bool clearLocation = false,
  }) {
    return CaptureState(
      memoryType: memoryType ?? this.memoryType,
      rawTranscript: clearTranscript
          ? null
          : (rawTranscript ?? this.rawTranscript),
      description: clearDescription
          ? null
          : (description ?? this.description),
      photoPaths: photoPaths ?? this.photoPaths,
      videoPaths: videoPaths ?? this.videoPaths,
      tags: tags ?? this.tags,
      isDictating: isDictating ?? this.isDictating,
      captureStartTime: captureStartTime ?? this.captureStartTime,
      capturedAt: capturedAt ?? this.capturedAt,
      latitude: clearLocation ? null : (latitude ?? this.latitude),
      longitude: clearLocation ? null : (longitude ?? this.longitude),
      locationStatus: clearLocation ? null : (locationStatus ?? this.locationStatus),
      hasUnsavedChanges: hasUnsavedChanges ?? this.hasUnsavedChanges,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  /// Check if there's enough content to enable Save
  /// Save is enabled if there's at least: transcript, description, photos, videos, or tags
  bool get canSave {
    return (rawTranscript?.trim().isNotEmpty ?? false) ||
        (description?.trim().isNotEmpty ?? false) ||
        photoPaths.isNotEmpty ||
        videoPaths.isNotEmpty ||
        tags.isNotEmpty;
  }

  /// Check if photo limit has been reached (10 photos max)
  bool get canAddPhoto => photoPaths.length < 10;

  /// Check if video limit has been reached (3 videos max)
  bool get canAddVideo => videoPaths.length < 3;
}

