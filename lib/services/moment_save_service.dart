import 'dart:io';
import 'dart:async';
import 'package:memories/models/capture_state.dart';
import 'package:memories/models/memory_type.dart';
import 'package:memories/providers/supabase_provider.dart';
import 'package:memories/services/connectivity_service.dart';
import 'package:memories/services/title_generation_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

part 'moment_save_service.g.dart';

/// Result of saving a moment
class MomentSaveResult {
  final String momentId;
  final String? generatedTitle;
  final DateTime? titleGeneratedAt;
  final List<String> photoUrls;
  final List<String> videoUrls;
  final bool hasLocation;

  MomentSaveResult({
    required this.momentId,
    this.generatedTitle,
    this.titleGeneratedAt,
    required this.photoUrls,
    required this.videoUrls,
    required this.hasLocation,
  });
}

/// Progress callback for save operations
typedef SaveProgressCallback = void Function({
  String? message,
  double? progress,
});

/// Service for saving moments to Supabase
@riverpod
MomentSaveService momentSaveService(MomentSaveServiceRef ref) {
  final supabase = ref.watch(supabaseClientProvider);
  final titleService = ref.watch(titleGenerationServiceProvider);
  final connectivityService = ref.watch(connectivityServiceProvider);
  return MomentSaveService(
    supabase,
    titleService,
    connectivityService,
  );
}

class MomentSaveService {
  final SupabaseClient _supabase;
  final TitleGenerationService _titleService;
  final ConnectivityService _connectivityService;
  static const String _photosBucket = 'moments-photos';
  static const String _videosBucket = 'moments-videos';
  static const int _maxRetries = 3;
  static const Duration _uploadTimeout = Duration(seconds: 30);

  MomentSaveService(
    this._supabase,
    this._titleService,
    this._connectivityService,
  );

  /// Save a moment with all its metadata
  /// 
  /// This method:
  /// 1. Checks connectivity - queues if offline
  /// 2. Uploads photos and videos to Supabase Storage (with retry logic)
  /// 3. Creates the moment record in the database
  /// 4. Optionally generates a title if transcript is available
  /// 
  /// Returns the saved moment ID and generated title (if any)
  /// Throws OfflineException if offline (caller should handle queueing)
  Future<MomentSaveResult> saveMoment({
    required CaptureState state,
    SaveProgressCallback? onProgress,
  }) async {
    // Check connectivity first
    final isOnline = await _connectivityService.isOnline();
    if (!isOnline) {
      throw OfflineException('Device is offline. Moment will be queued for sync.');
    }

    try {
      // Step 1: Upload media files
      onProgress?.call(message: 'Uploading media...', progress: 0.1);
      final photoUrls = <String>[];
      final videoUrls = <String>[];

      // Upload photos with retry logic
      for (int i = 0; i < state.photoPaths.length; i++) {
        final photoPath = state.photoPaths[i];
        final file = File(photoPath);
        if (!await file.exists()) {
          continue;
        }

        final fileName = '${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        final storagePath = '${_supabase.auth.currentUser?.id}/$fileName';

        // Retry upload with exponential backoff
        String? publicUrl;
        Exception? lastError;
        
        for (int attempt = 0; attempt < _maxRetries; attempt++) {
          try {
            await _supabase.storage.from(_photosBucket).upload(
              storagePath,
              file,
              fileOptions: const FileOptions(
                upsert: false,
                contentType: 'image/jpeg',
              ),
            ).timeout(_uploadTimeout);

            publicUrl = _supabase.storage.from(_photosBucket).getPublicUrl(storagePath);
            break; // Success, exit retry loop
          } catch (e) {
            lastError = e is Exception ? e : Exception(e.toString());
            if (attempt < _maxRetries - 1) {
              // Exponential backoff: 1s, 2s, 4s
              final delay = Duration(seconds: 1 << attempt);
              await Future.delayed(delay);
              onProgress?.call(
                message: 'Retrying photo upload... (${i + 1}/${state.photoPaths.length})',
                progress: 0.1 + (0.3 * (i + 1) / state.photoPaths.length),
              );
            }
          }
        }

        if (publicUrl == null) {
          throw Exception('Failed to upload photo after $_maxRetries attempts: ${lastError?.toString() ?? 'Unknown error'}');
        }

        photoUrls.add(publicUrl);

        onProgress?.call(
          message: 'Uploading photos... (${i + 1}/${state.photoPaths.length})',
          progress: 0.1 + (0.3 * (i + 1) / state.photoPaths.length),
        );
      }

      // Upload videos with retry logic
      for (int i = 0; i < state.videoPaths.length; i++) {
        final videoPath = state.videoPaths[i];
        final file = File(videoPath);
        if (!await file.exists()) {
          continue;
        }

        final fileName = '${DateTime.now().millisecondsSinceEpoch}_$i.mp4';
        final storagePath = '${_supabase.auth.currentUser?.id}/$fileName';

        // Retry upload with exponential backoff
        String? publicUrl;
        Exception? lastError;
        
        for (int attempt = 0; attempt < _maxRetries; attempt++) {
          try {
            await _supabase.storage.from(_videosBucket).upload(
              storagePath,
              file,
              fileOptions: const FileOptions(
                upsert: false,
                contentType: 'video/mp4',
              ),
            ).timeout(_uploadTimeout);

            publicUrl = _supabase.storage.from(_videosBucket).getPublicUrl(storagePath);
            break; // Success, exit retry loop
          } catch (e) {
            lastError = e is Exception ? e : Exception(e.toString());
            if (attempt < _maxRetries - 1) {
              // Exponential backoff: 1s, 2s, 4s
              final delay = Duration(seconds: 1 << attempt);
              await Future.delayed(delay);
              onProgress?.call(
                message: 'Retrying video upload... (${i + 1}/${state.videoPaths.length})',
                progress: 0.4 + (0.2 * (i + 1) / state.videoPaths.length),
              );
            }
          }
        }

        if (publicUrl == null) {
          throw Exception('Failed to upload video after $_maxRetries attempts: ${lastError?.toString() ?? 'Unknown error'}');
        }

        videoUrls.add(publicUrl);

        onProgress?.call(
          message: 'Uploading videos... (${i + 1}/${state.videoPaths.length})',
          progress: 0.4 + (0.2 * (i + 1) / state.videoPaths.length),
        );
      }

      // Step 2: Prepare location data
      String? locationWkt;
      if (state.latitude != null && state.longitude != null) {
        // Format as PostGIS Point WKT: POINT(longitude latitude)
        locationWkt = 'POINT(${state.longitude} ${state.latitude})';
      }

      // Step 3: Create moment record
      onProgress?.call(message: 'Saving moment...', progress: 0.7);
      final now = DateTime.now().toUtc();
      
      final momentData = {
        'user_id': _supabase.auth.currentUser?.id,
        'title': '', // Will be updated after title generation
        'text_description': state.description,
        'raw_transcript': state.rawTranscript,
        'photo_urls': photoUrls,
        'video_urls': videoUrls,
        'tags': state.tags,
        'capture_type': state.memoryType.apiValue,
        'location_status': state.locationStatus,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };

      // Add location if available (PostGIS geography format)
      if (locationWkt != null) {
        momentData['captured_location'] = locationWkt;
      }

      final response = await _supabase
          .from('moments')
          .insert(momentData)
          .select('id')
          .single();

      final momentId = response['id'] as String;

      // Step 4: Generate title if transcript exists
      String? generatedTitle;
      DateTime? titleGeneratedAt;
      
      if (state.rawTranscript != null && state.rawTranscript!.trim().isNotEmpty) {
        onProgress?.call(message: 'Generating title...', progress: 0.85);
        
        try {
          final titleResponse = await _titleService.generateTitle(
            transcript: state.rawTranscript!,
            memoryType: state.memoryType,
          );
          
          generatedTitle = titleResponse.title;
          titleGeneratedAt = titleResponse.generatedAt;

          // Update moment with generated title
          await _supabase
              .from('moments')
              .update({
                'title': generatedTitle,
                'generated_title': generatedTitle,
                'title_generated_at': titleGeneratedAt.toIso8601String(),
              })
              .eq('id', momentId);
        } catch (e) {
          // Title generation failed, use fallback
          final fallbackTitle = _getFallbackTitle(state.memoryType);
          generatedTitle = fallbackTitle;
          
          await _supabase
              .from('moments')
              .update({
                'title': fallbackTitle,
              })
              .eq('id', momentId);
        }
      } else {
        // No transcript, use fallback title
        final fallbackTitle = _getFallbackTitle(state.memoryType);
        generatedTitle = fallbackTitle;
        
        await _supabase
            .from('moments')
            .update({
              'title': fallbackTitle,
            })
            .eq('id', momentId);
      }

      onProgress?.call(message: 'Complete!', progress: 1.0);

      return MomentSaveResult(
        momentId: momentId,
        generatedTitle: generatedTitle,
        titleGeneratedAt: titleGeneratedAt,
        photoUrls: photoUrls,
        videoUrls: videoUrls,
        hasLocation: locationWkt != null,
      );
    } on OfflineException {
      rethrow;
    } catch (e) {
      final errorString = e.toString();
      
      // Handle storage quota errors
      if (errorString.contains('413') || 
          errorString.contains('quota') || 
          errorString.contains('limit')) {
        throw StorageQuotaException('Storage limit reached. Please delete some memories.');
      }
      
      // Handle permission errors
      if (errorString.contains('403') || 
          errorString.contains('permission')) {
        throw PermissionException('Permission denied. Please check app settings.');
      }
      
      // Handle network errors
      if (errorString.contains('SocketException') || 
          errorString.contains('TimeoutException') ||
          errorString.contains('network')) {
        throw NetworkException('Network error. Check your connection and try again.');
      }
      
      // Generic error
      throw SaveException('Failed to save moment: ${e.toString()}');
    }
  }

  String _getFallbackTitle(MemoryType memoryType) {
    switch (memoryType) {
      case MemoryType.moment:
        return 'Untitled Moment';
      case MemoryType.story:
        return 'Untitled Story';
      case MemoryType.memento:
        return 'Untitled Memento';
    }
  }
}

/// Exception thrown when device is offline
class OfflineException implements Exception {
  final String message;
  OfflineException(this.message);
  
  @override
  String toString() => message;
}

/// Exception thrown when storage quota is exceeded
class StorageQuotaException implements Exception {
  final String message;
  StorageQuotaException(this.message);
  
  @override
  String toString() => message;
}

/// Exception thrown when permission is denied
class PermissionException implements Exception {
  final String message;
  PermissionException(this.message);
  
  @override
  String toString() => message;
}

/// Exception thrown for network errors
class NetworkException implements Exception {
  final String message;
  NetworkException(this.message);
  
  @override
  String toString() => message;
}

/// Generic exception for save failures
class SaveException implements Exception {
  final String message;
  SaveException(this.message);
  
  @override
  String toString() => message;
}

