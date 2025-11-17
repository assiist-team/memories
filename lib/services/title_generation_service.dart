import 'package:memories/models/memory_type.dart';
import 'package:memories/providers/supabase_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'title_generation_service.g.dart';

/// Response from title generation edge function
class TitleGenerationResponse {
  final String title;
  final String status; // 'success' or 'fallback'
  final DateTime generatedAt;

  TitleGenerationResponse({
    required this.title,
    required this.status,
    required this.generatedAt,
  });

  factory TitleGenerationResponse.fromJson(Map<String, dynamic> json) {
    return TitleGenerationResponse(
      title: json['title'] as String,
      status: json['status'] as String,
      generatedAt: DateTime.parse(json['generatedAt'] as String),
    );
  }
}

/// Service for generating titles from transcripts using the Supabase edge function
@riverpod
TitleGenerationService titleGenerationService(TitleGenerationServiceRef ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return TitleGenerationService(supabase);
}

class TitleGenerationService {
  final SupabaseClient _supabase;

  TitleGenerationService(this._supabase);

  /// Generate a title from a transcript
  /// 
  /// Returns the generated title or throws an exception on error
  Future<TitleGenerationResponse> generateTitle({
    required String transcript,
    required MemoryType memoryType,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'generate-title',
        body: {
          'transcript': transcript.trim(),
          'memoryType': memoryType.apiValue,
        },
      );

      if (response.status != 200) {
        final errorData = response.data as Map<String, dynamic>?;
        final errorMessage = errorData?['message'] as String? ?? 
            'Failed to generate title';
        throw Exception(errorMessage);
      }

      final data = response.data as Map<String, dynamic>;
      return TitleGenerationResponse.fromJson(data);
    } catch (e) {
      // Re-throw with context
      throw Exception('Title generation failed: ${e.toString()}');
    }
  }
}

