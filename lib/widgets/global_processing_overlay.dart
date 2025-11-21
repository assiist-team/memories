import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memories/models/memory_processing_status.dart';
import 'package:memories/models/memory_type.dart';
import 'package:memories/providers/memory_processing_status_provider.dart';
import 'package:memories/services/connectivity_service.dart';

/// Global overlay widget that shows background processing status
/// 
/// Appears near the bottom of the screen when memories are being processed.
/// Non-modal and can be dismissed by the user.
class GlobalProcessingOverlay extends ConsumerStatefulWidget {
  final Widget child;

  const GlobalProcessingOverlay({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<GlobalProcessingOverlay> createState() =>
      _GlobalProcessingOverlayState();
}

class _GlobalProcessingOverlayState
    extends ConsumerState<GlobalProcessingOverlay> {
  bool _isDismissed = false;
  String? _dismissedMemoryId;

  @override
  Widget build(BuildContext context) {
    final connectivityService = ref.watch(connectivityServiceProvider);
    final activeStatusesAsync = ref.watch(activeProcessingStatusesStreamProvider);

    return FutureBuilder<bool>(
      future: connectivityService.isOnline(),
      builder: (context, snapshot) {
        final isOnline = snapshot.data ?? false;

        return Stack(
          children: [
            widget.child,
            // Only show overlay when online and there are active processing statuses
            if (isOnline)
              activeStatusesAsync.when(
                data: (statuses) {
                  if (statuses.isEmpty || _isDismissed) {
                    return const SizedBox.shrink();
                  }

                  // Show the most recent processing memory
                  final mostRecent = statuses.first;
                  
                  // Don't show if this memory was dismissed
                  if (_dismissedMemoryId == mostRecent.memoryId) {
                    return const SizedBox.shrink();
                  }

                  // Don't show if processing is complete
                  if (mostRecent.isComplete) {
                    return const SizedBox.shrink();
                  }

                  return Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: _ProcessingStatusBanner(
                          status: mostRecent,
                          onDismiss: () {
                            setState(() {
                              _isDismissed = true;
                              _dismissedMemoryId = mostRecent.memoryId;
                            });
                          },
                        ),
                      ),
                    ),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
          ],
        );
      },
    );
  }
}

class _ProcessingStatusBanner extends StatelessWidget {
  final MemoryProcessingStatus status;
  final VoidCallback onDismiss;

  const _ProcessingStatusBanner({
    required this.status,
    required this.onDismiss,
  });

  String _getStatusMessage() {
    switch (status.state) {
      case MemoryProcessingState.queued:
        return 'Queued for processing…';
      case MemoryProcessingState.processing:
        // Check metadata for phase information
        final phase = status.phase;
        if (phase != null) {
          switch (phase) {
            case 'title':
            case 'title_generation':
              return 'Generating title…';
            case 'text':
            case 'text_processing':
              return 'Processing text…';
            case 'narrative':
              return 'Generating narrative…';
            default:
              return 'Processing in background…';
          }
        }
        return 'Processing in background…';
      case MemoryProcessingState.failed:
        return 'Processing failed. We\'ll retry automatically.';
      case MemoryProcessingState.complete:
        return 'Processing complete';
    }
  }

  Color _getStatusColor() {
    switch (status.state) {
      case MemoryProcessingState.queued:
        return Colors.blue;
      case MemoryProcessingState.processing:
        return Colors.blue;
      case MemoryProcessingState.failed:
        return Colors.red;
      case MemoryProcessingState.complete:
        return Colors.green;
    }
  }

  IconData _getStatusIcon() {
    switch (status.state) {
      case MemoryProcessingState.queued:
        return Icons.hourglass_empty;
      case MemoryProcessingState.processing:
        return Icons.sync;
      case MemoryProcessingState.failed:
        return Icons.error_outline;
      case MemoryProcessingState.complete:
        return Icons.check_circle;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = _getStatusColor();
    final statusIcon = _getStatusIcon();
    final statusMessage = _getStatusMessage();

    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(12),
      color: theme.colorScheme.surface,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: statusColor.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Status icon with animation for processing state
            if (status.state == MemoryProcessingState.processing)
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                ),
              )
            else
              Icon(
                statusIcon,
                size: 20,
                color: statusColor,
              ),
            const SizedBox(width: 12),
            // Status message
            Expanded(
              child: Text(
                statusMessage,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            // Dismiss button
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              color: theme.colorScheme.onSurfaceVariant,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: onDismiss,
            ),
          ],
        ),
      ),
    );
  }
}

