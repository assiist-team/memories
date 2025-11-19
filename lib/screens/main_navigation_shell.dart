import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memories/screens/capture/capture_screen.dart';
import 'package:memories/screens/timeline/unified_timeline_screen.dart';
import 'package:memories/screens/settings/settings_screen.dart';
import 'package:memories/providers/main_navigation_provider.dart';

/// Main navigation shell that provides bottom navigation between main app screens
/// 
/// Provides navigation between:
/// - Capture screen (default)
/// - Timeline screen
/// - Settings screen
class MainNavigationShell extends ConsumerStatefulWidget {
  const MainNavigationShell({super.key});

  @override
  ConsumerState<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends ConsumerState<MainNavigationShell> {
  final List<Widget> _screens = const [
    CaptureScreen(),
    UnifiedTimelineScreen(),
    SettingsScreen(),
  ];

  int _getTabIndex(MainNavigationTab tab) {
    switch (tab) {
      case MainNavigationTab.capture:
        return 0;
      case MainNavigationTab.timeline:
        return 1;
      case MainNavigationTab.settings:
        return 2;
    }
  }

  MainNavigationTab _getTabFromIndex(int index) {
    switch (index) {
      case 0:
        return MainNavigationTab.capture;
      case 1:
        return MainNavigationTab.timeline;
      case 2:
        return MainNavigationTab.settings;
      default:
        return MainNavigationTab.capture;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedTab = ref.watch(mainNavigationTabNotifierProvider);
    final currentIndex = _getTabIndex(selectedTab);

    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          final tab = _getTabFromIndex(index);
          ref.read(mainNavigationTabNotifierProvider.notifier).setTab(tab);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.camera_alt_outlined),
            selectedIcon: Icon(Icons.camera_alt),
            label: 'Capture',
          ),
          NavigationDestination(
            icon: Icon(Icons.timeline_outlined),
            selectedIcon: Icon(Icons.timeline),
            label: 'Timeline',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

