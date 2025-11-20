import 'package:flutter/material.dart';

/// Enum representing the different types of memories in the app
enum MemoryType {
  /// A moment - a snapshot in time with optional text, photos, and videos
  moment,
  
  /// A story - a narrative experience with audio and processed text
  story,
  
  /// A memento - a meaningful object with photo and description
  memento,
}

/// Extension to convert MemoryType to/from string for API calls
extension MemoryTypeExtension on MemoryType {
  /// Convert MemoryType to string for API calls
  String get apiValue {
    switch (this) {
      case MemoryType.moment:
        return 'moment';
      case MemoryType.story:
        return 'story';
      case MemoryType.memento:
        return 'memento';
    }
  }
  
  /// Convert string to MemoryType from API responses
  static MemoryType fromApiValue(String value) {
    switch (value.toLowerCase()) {
      case 'moment':
        return MemoryType.moment;
      case 'story':
        return MemoryType.story;
      case 'memento':
        return MemoryType.memento;
      default:
        return MemoryType.moment;
    }
  }
  
  /// Get display name for UI
  String get displayName {
    switch (this) {
      case MemoryType.moment:
        return 'Moment';
      case MemoryType.story:
        return 'Story';
      case MemoryType.memento:
        return 'Memento';
    }
  }
  
  /// Get icon for UI
  IconData get icon {
    switch (this) {
      case MemoryType.moment:
        return Icons.access_time;
      case MemoryType.story:
        return Icons.edit;
      case MemoryType.memento:
        return Icons.inventory_2;
    }
  }
}

