import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:memories/models/memory_processing_status.dart';
import 'package:memories/providers/supabase_provider.dart';
import 'package:memories/services/connectivity_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'memory_processing_status_provider.g.dart';

/// Provider for memory processing status service
@riverpod
MemoryProcessingStatusService memoryProcessingStatusService(
    MemoryProcessingStatusServiceRef ref) {
  final supabase = ref.read(supabaseClientProvider);
  final connectivityService = ref.read(connectivityServiceProvider);
  return MemoryProcessingStatusService(supabase, connectivityService);
}

/// Service for fetching and watching memory processing status
class MemoryProcessingStatusService {
  final SupabaseClient _supabase;
  final ConnectivityService _connectivityService;
  final Map<String, RealtimeChannel> _channels = {};

  MemoryProcessingStatusService(this._supabase, this._connectivityService);

  /// Get processing status for a specific memory
  Future<MemoryProcessingStatus?> getStatus(String memoryId) async {
    try {
      final isOnline = await _connectivityService.isOnline();
      if (!isOnline) return null;

      final response = await _supabase
          .from('memory_processing_status')
          .select()
          .eq('memory_id', memoryId)
          .maybeSingle();

      if (response == null) return null;
      return MemoryProcessingStatus.fromJson(response);
    } catch (e) {
      debugPrint('Error fetching processing status: $e');
      return null;
    }
  }

  /// Get all processing statuses for memories that are currently processing
  Future<List<MemoryProcessingStatus>> getActiveProcessingStatuses() async {
    try {
      final isOnline = await _connectivityService.isOnline();
      if (!isOnline) return [];

      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      // Get memories for current user first
      final memories = await _supabase
          .from('memories')
          .select('id')
          .eq('user_id', userId);

      if (memories.isEmpty) return [];

      final memoryIds = (memories as List)
          .map((m) => m['id'] as String)
          .toSet(); // Use Set for faster lookup

      if (memoryIds.isEmpty) return [];

      // Get all processing statuses and filter client-side
      // Query for scheduled and processing states separately
      final scheduledStatuses = await _supabase
          .from('memory_processing_status')
          .select()
          .eq('state', 'scheduled');

      final processingStatuses = await _supabase
          .from('memory_processing_status')
          .select()
          .eq('state', 'processing');

      final allStatuses = <Map<String, dynamic>>[];
      allStatuses.addAll((scheduledStatuses as List).cast<Map<String, dynamic>>());
      allStatuses.addAll((processingStatuses as List).cast<Map<String, dynamic>>());

      // Filter to only user's memories and sort by created_at descending
      final userStatuses = allStatuses
          .where((s) => memoryIds.contains(s['memory_id'] as String))
          .toList();

      if (userStatuses.isEmpty) return [];

      userStatuses.sort((a, b) {
        final aTime = DateTime.parse(a['created_at'] as String);
        final bTime = DateTime.parse(b['created_at'] as String);
        return bTime.compareTo(aTime);
      });

      return userStatuses
          .map((json) => MemoryProcessingStatus.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error fetching active processing statuses: $e');
      return [];
    }
  }

  /// Watch processing status for a specific memory using real-time
  Stream<MemoryProcessingStatus?> watchStatus(String memoryId) {
    final controller = StreamController<MemoryProcessingStatus?>();

    // Initial fetch
    getStatus(memoryId).then((status) {
      if (!controller.isClosed) {
        controller.add(status);
      }
    });

    // Set up real-time subscription
    final channel = _supabase
        .channel('memory_processing_status_$memoryId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'memory_processing_status',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'memory_id',
            value: memoryId,
          ),
          callback: (payload) {
            try {
              final status = MemoryProcessingStatus.fromJson(
                payload.newRecord,
              );
              controller.add(status);
            } catch (e) {
              debugPrint('Error parsing processing status update: $e');
              // Status was deleted or invalid
              controller.add(null);
            }
          },
        )
        .subscribe();

    _channels[memoryId] = channel;

    // Clean up on cancel
    controller.onCancel = () {
      channel.unsubscribe();
      _channels.remove(memoryId);
    };

    return controller.stream;
  }

  /// Watch all active processing statuses for the current user
  Stream<List<MemoryProcessingStatus>> watchActiveProcessingStatuses() {
    final controller = StreamController<List<MemoryProcessingStatus>>();

    // Initial fetch
    getActiveProcessingStatuses().then((statuses) {
      if (!controller.isClosed) {
        controller.add(statuses);
      }
    });

    // Set up real-time subscription for all processing statuses
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      controller.add([]);
      return controller.stream;
    }

    // Set up real-time subscription for all processing statuses
    // Listen to all changes and filter client-side for scheduled and processing states
    final channel = _supabase
        .channel('memory_processing_status_all')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'memory_processing_status',
          callback: (payload) async {
            try {
              // Check if the change is for a state we care about
              final newRecord = payload.newRecord as Map<String, dynamic>?;
              final oldRecord = payload.oldRecord as Map<String, dynamic>?;
              
              final state = newRecord?['state'] as String? ?? oldRecord?['state'] as String?;
              if (state != null && (state == 'scheduled' || state == 'processing')) {
                // Refetch all active statuses to ensure we have user filtering
                final statuses = await getActiveProcessingStatuses();
                if (!controller.isClosed) {
                  controller.add(statuses);
                }
              }
            } catch (e) {
              debugPrint('Error updating active processing statuses: $e');
            }
          },
        )
        .subscribe();

    // Clean up on cancel
    controller.onCancel = () {
      channel.unsubscribe();
    };

    return controller.stream;
  }

  /// Dispose all channels
  void dispose() {
    for (final channel in _channels.values) {
      channel.unsubscribe();
    }
    _channels.clear();
  }
}

/// Provider for a specific memory's processing status
@riverpod
Stream<MemoryProcessingStatus?> memoryProcessingStatusStream(
    MemoryProcessingStatusStreamRef ref, String memoryId) {
  final service = ref.read(memoryProcessingStatusServiceProvider);
  return service.watchStatus(memoryId);
}

/// Provider for all active processing statuses
@riverpod
Stream<List<MemoryProcessingStatus>> activeProcessingStatusesStream(
    ActiveProcessingStatusesStreamRef ref) {
  final service = ref.read(memoryProcessingStatusServiceProvider);
  return service.watchActiveProcessingStatuses();
}

