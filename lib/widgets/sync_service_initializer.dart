import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memories/services/moment_sync_service.dart';

/// Widget that initializes the sync service when mounted
/// 
/// This should be used in the authenticated app shell to start
/// automatic syncing of queued moments.
class SyncServiceInitializer extends ConsumerStatefulWidget {
  final Widget child;

  const SyncServiceInitializer({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<SyncServiceInitializer> createState() => _SyncServiceInitializerState();
}

class _SyncServiceInitializerState extends ConsumerState<SyncServiceInitializer> {
  @override
  void initState() {
    super.initState();
    // Initialize sync service after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final syncService = ref.read(momentSyncServiceProvider);
      syncService.startAutoSync();
    });
  }

  @override
  void dispose() {
    // Stop auto sync when widget is disposed
    final syncService = ref.read(momentSyncServiceProvider);
    syncService.stopAutoSync();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

