import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memories/models/memory_type.dart';
import 'package:memories/providers/unified_feed_tab_provider.dart';

/// Segmented control for unified feed filter tabs
/// 
/// Provides multi-select tabs: Stories, Moments, Mementos
/// All three are selected by default. Users can deselect types to filter.
/// Connects to UnifiedFeedTabNotifier for state management
class UnifiedFeedSegmentedControl extends ConsumerWidget {
  const UnifiedFeedSegmentedControl({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedTypes = ref.watch(unifiedFeedTabNotifierProvider).valueOrNull ?? {
      MemoryType.story,
      MemoryType.moment,
      MemoryType.memento,
    };

    final theme = Theme.of(context);
    final scaffoldBackground = theme.scaffoldBackgroundColor;

    return Container(
      decoration: BoxDecoration(
        color: scaffoldBackground,
      ),
      child: Semantics(
        label: 'Memory type filter',
        child: SegmentedButton<MemoryType>(
          style: SegmentedButton.styleFrom(
            selectedBackgroundColor: const Color(0xFF2B2B2B),
            selectedForegroundColor: const Color(0xFFFFFFFF),
            backgroundColor: scaffoldBackground,
            foregroundColor: theme.colorScheme.onSurfaceVariant,
          ),
          multiSelectionEnabled: true,
          segments: [
            ButtonSegment<MemoryType>(
              value: MemoryType.moment,
              label: Text(MemoryType.moment.displayName),
              icon: Icon(MemoryType.moment.icon),
            ),
            ButtonSegment<MemoryType>(
              value: MemoryType.story,
              label: Text(MemoryType.story.displayName),
              icon: Icon(MemoryType.story.icon),
            ),
            ButtonSegment<MemoryType>(
              value: MemoryType.memento,
              label: Text(MemoryType.memento.displayName),
              icon: Icon(MemoryType.memento.icon),
            ),
          ],
          selected: selectedTypes,
          onSelectionChanged: (Set<MemoryType> selection) {
            // Ensure at least one type is always selected
            if (selection.isNotEmpty) {
              ref.read(unifiedFeedTabNotifierProvider.notifier).setSelectedTypes(selection);
            }
            // If user tries to deselect all, keep the current selection
          },
        ),
      ),
    );
  }
}

