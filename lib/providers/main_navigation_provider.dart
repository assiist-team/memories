import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'main_navigation_provider.g.dart';

/// Enum representing the main navigation tabs
enum MainNavigationTab {
  /// Capture screen (index 0)
  capture,
  
  /// Timeline screen (index 1)
  timeline,
  
  /// Settings screen (index 2)
  settings,
}

/// Provider for managing the selected tab in MainNavigationShell
/// 
/// Allows any screen to switch to a different tab programmatically.
@riverpod
class MainNavigationTabNotifier extends _$MainNavigationTabNotifier {
  @override
  MainNavigationTab build() {
    // Default to capture tab on app start
    return MainNavigationTab.capture;
  }

  /// Switch to the specified tab
  void setTab(MainNavigationTab tab) {
    state = tab;
  }

  /// Switch to the capture tab
  void switchToCapture() {
    setTab(MainNavigationTab.capture);
  }

  /// Switch to the timeline tab
  void switchToTimeline() {
    setTab(MainNavigationTab.timeline);
  }

  /// Switch to the settings tab
  void switchToSettings() {
    setTab(MainNavigationTab.settings);
  }
}

