import 'package:memories/providers/supabase_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'memory_processing_service.g.dart';

/// Response from memory processing edge functions
class MemoryProcessingResponse {
  final String title;
  final String processedText;
  final String status; // 'success' | 'fallback' | 'partial' | 'failed'
  final DateTime generatedAt;

  MemoryProcessingResponse({
    required this.title,
    required this.processedText,
    required this.status,
    required this.generatedAt,
  });

  factory MemoryProcessingResponse.fromJson(Map<String, dynamic> json) {
    return MemoryProcessingResponse(
      title: json['title'] as String,
      processedText: json['processedText'] as String,
      status: json['status'] as String,
      generatedAt: DateTime.parse(json['generatedAt'] as String),
    );
  }
}

/// Service for processing memories using type-specific edge functions
@riverpod
MemoryProcessingService memoryProcessingService(
    MemoryProcessingServiceRef ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return MemoryProcessingService(supabase);
}

class MemoryProcessingService {
  final SupabaseClient _supabase;

  MemoryProcessingService(this._supabase);

  /// Process a moment: generates processed_text and title
  ///
  /// Returns the processing result or throws an exception on error
  Future<MemoryProcessingResponse> processMoment({
    required String memoryId,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'process-moment',
        body: {
          'memoryId': memoryId,
        },
      );

      if (response.status != 200) {
        final errorData = response.data as Map<String, dynamic>?;
        final errorMessage =
            errorData?['message'] as String? ?? 'Failed to process moment';
        throw Exception(errorMessage);
      }

      final data = response.data as Map<String, dynamic>;
      return MemoryProcessingResponse.fromJson(data);
    } catch (e) {
      throw Exception('Moment processing failed: ${e.toString()}');
    }
  }

  /// Process a memento: generates processed_text and title
  ///
  /// Returns the processing result or throws an exception on error
  Future<MemoryProcessingResponse> processMemento({
    required String memoryId,
  }) async {
    try {
      print(
          'DEBUG: Calling process-memento edge function for memoryId: $memoryId');
      final response = await _supabase.functions.invoke(
        'process-memento',
        body: {
          'memoryId': memoryId,
        },
      );

      print('DEBUG: process-memento response status: ${response.status}');
      print('DEBUG: process-memento response data: ${response.data}');

      if (response.status != 200) {
        final errorData = response.data as Map<String, dynamic>?;
        final errorMessage =
            errorData?['message'] as String? ?? 'Failed to process memento';
        print(
            'ERROR: process-memento failed with status ${response.status}: $errorMessage');
        throw Exception(errorMessage);
      }

      final data = response.data as Map<String, dynamic>;
      return MemoryProcessingResponse.fromJson(data);
    } catch (e, stackTrace) {
      print('ERROR: Exception in processMemento: $e');
      print('ERROR: Stack trace: $stackTrace');
      throw Exception('Memento processing failed: ${e.toString()}');
    }
  }

  /// Process a story: generates narrative (processed_text) and title
  ///
  /// Returns the processing result or throws an exception on error
  /// Note: Story processing is asynchronous and may take longer than moment/memento processing
  Future<MemoryProcessingResponse> processStory({
    required String memoryId,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'process-story',
        body: {
          'memoryId': memoryId,
        },
      );

      if (response.status != 200) {
        final errorData = response.data as Map<String, dynamic>?;
        final errorMessage =
            errorData?['message'] as String? ?? 'Failed to process story';
        throw Exception(errorMessage);
      }

      final data = response.data as Map<String, dynamic>;
      return MemoryProcessingResponse.fromJson(data);
    } catch (e) {
      throw Exception('Story processing failed: ${e.toString()}');
    }
  }
}
