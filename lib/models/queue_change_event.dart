/// Type of queue change event
enum QueueChangeType {
  /// A memory was added to the queue
  added,
  
  /// A queued memory was updated
  updated,
  
  /// A queued memory was removed from the queue
  removed,
}

/// Event representing a change to the offline queue
class QueueChangeEvent {
  /// Local ID of the memory that changed
  final String localId;
  
  /// Type of memory (moment, story, memento)
  final String memoryType;
  
  /// Type of change that occurred
  final QueueChangeType type;

  QueueChangeEvent({
    required this.localId,
    required this.memoryType,
    required this.type,
  });
}

