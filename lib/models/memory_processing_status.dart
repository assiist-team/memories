/// Processing state for a memory
enum MemoryProcessingState {
  scheduled,
  processing,
  complete,
  failed;

  static MemoryProcessingState fromString(String value) {
    switch (value.toLowerCase()) {
      case 'scheduled':
        return MemoryProcessingState.scheduled;
      case 'processing':
        return MemoryProcessingState.processing;
      case 'complete':
        return MemoryProcessingState.complete;
      case 'failed':
        return MemoryProcessingState.failed;
      default:
        return MemoryProcessingState.scheduled;
    }
  }

  String toApiValue() {
    switch (this) {
      case MemoryProcessingState.scheduled:
        return 'scheduled';
      case MemoryProcessingState.processing:
        return 'processing';
      case MemoryProcessingState.complete:
        return 'complete';
      case MemoryProcessingState.failed:
        return 'failed';
    }
  }
}

/// Model representing the processing status of a memory
class MemoryProcessingStatus {
  final String memoryId;
  final MemoryProcessingState state;
  final int attempts;
  final String? lastError;
  final DateTime? lastErrorAt;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime lastUpdatedAt;
  final Map<String, dynamic>? metadata;

  MemoryProcessingStatus({
    required this.memoryId,
    required this.state,
    this.attempts = 0,
    this.lastError,
    this.lastErrorAt,
    required this.createdAt,
    this.startedAt,
    this.completedAt,
    required this.lastUpdatedAt,
    this.metadata,
  });

  factory MemoryProcessingStatus.fromJson(Map<String, dynamic> json) {
    return MemoryProcessingStatus(
      memoryId: json['memory_id'] as String,
      state: MemoryProcessingState.fromString(
        json['state'] as String? ?? 'scheduled',
      ),
      attempts: json['attempts'] as int? ?? 0,
      lastError: json['last_error'] as String?,
      lastErrorAt: json['last_error_at'] != null
          ? DateTime.parse(json['last_error_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      startedAt: json['started_at'] != null
          ? DateTime.parse(json['started_at'] as String)
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      lastUpdatedAt: DateTime.parse(json['last_updated_at'] as String),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'memory_id': memoryId,
      'state': state.toApiValue(),
      'attempts': attempts,
      'last_error': lastError,
      'last_error_at': lastErrorAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'started_at': startedAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'last_updated_at': lastUpdatedAt.toIso8601String(),
      'metadata': metadata,
    };
  }

  /// Get the current processing phase from metadata if available
  String? get phase {
    if (metadata == null) return null;
    return metadata!['phase'] as String?;
  }

  /// Check if processing is actively in progress.
  ///
  /// We intentionally treat only the `processing` state as "in progress"
  /// for UI purposes. A `scheduled` job means we have created a row and
  /// plan to process it, but no worker has actually started yet. Showing
  /// a spinner for `scheduled` creates the illusion of work that may not
  /// have started (especially if the dispatcher is misconfigured).
  bool get isInProgress {
    return state == MemoryProcessingState.processing;
  }

  /// Check if processing is complete
  bool get isComplete => state == MemoryProcessingState.complete;

  /// Check if processing has failed
  bool get hasFailed => state == MemoryProcessingState.failed;
}
