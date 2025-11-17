import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memories/providers/queue_status_provider.dart';

/// Widget that displays queue status chips
/// 
/// Shows "Queued", "Syncing", and "Needs Attention" status chips
/// based on the current state of the offline queue.
class QueueStatusChips extends ConsumerWidget {
  const QueueStatusChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueStatusAsync = ref.watch(queueStatusProvider);

    return queueStatusAsync.when(
      data: (status) {
        if (!status.hasItems) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (status.hasQueued)
                _StatusChip(
                  label: 'Queued',
                  count: status.queuedCount,
                  color: Colors.orange,
                  icon: Icons.queue,
                ),
              if (status.hasSyncing)
                _StatusChip(
                  label: 'Syncing',
                  count: status.syncingCount,
                  color: Colors.blue,
                  icon: Icons.sync,
                ),
              if (status.hasFailed)
                _StatusChip(
                  label: 'Needs Attention',
                  count: status.failedCount,
                  color: Colors.red,
                  icon: Icons.warning,
                ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;

  const _StatusChip({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18, color: color),
      label: Text(
        count > 1 ? '$label ($count)' : label,
        style: TextStyle(color: color),
      ),
      backgroundColor: color.withOpacity(0.1),
      side: BorderSide(color: color.withOpacity(0.3)),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }
}

