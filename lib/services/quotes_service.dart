import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:memories/providers/supabase_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'quotes_service.g.dart';

/// Model for a quote
class Quote {
  final String id;
  final String text;
  final String? author;

  Quote({
    required this.id,
    required this.text,
    this.author,
  });

  factory Quote.fromJson(Map<String, dynamic> json) {
    return Quote(
      id: json['id'] as String,
      text: json['text'] as String,
      author: json['author'] as String?,
    );
  }
}

/// Service for fetching inspirational quotes
@riverpod
QuotesService quotesService(QuotesServiceRef ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return QuotesService(supabase);
}

class QuotesService {
  final SupabaseClient _supabase;

  QuotesService(this._supabase);

  /// Get a random quote from the database
  /// 
  /// Returns a [Quote] or null if no quotes are available
  Future<Quote?> getRandomQuote() async {
    try {
      print('QuotesService.getRandomQuote: Starting query...');
      
      // Fetch all quotes and pick one randomly client-side
      // For a small dataset (20 quotes), this is efficient enough
      final response = await _supabase
          .from('quotes')
          .select('id, text, author');
      
      print('QuotesService.getRandomQuote: Fetched ${response.length} quotes');
      
      if (response.isEmpty) {
        print('QuotesService.getRandomQuote: Response is empty, returning null');
        return null;
      }
      
      // Pick a random quote using current time as seed
      final randomIndex = (DateTime.now().millisecondsSinceEpoch % response.length);
      final randomQuoteData = response[randomIndex];
      
      print('QuotesService.getRandomQuote: Selected random quote at index $randomIndex');
      print('QuotesService.getRandomQuote: Parsing quote from response: $randomQuoteData');
      
      final quote = Quote.fromJson(randomQuoteData);
      print('QuotesService.getRandomQuote: Successfully parsed quote: ${quote.text.substring(0, quote.text.length > 30 ? 30 : quote.text.length)}...');
      return quote;
    } catch (e, stack) {
      // Log error but don't throw - quotes are optional
      print('QuotesService.getRandomQuote: Error fetching quote: $e');
      print('QuotesService.getRandomQuote: Stack trace: $stack');
      return null;
    }
  }

  /// Get all quotes (for admin/debugging purposes)
  Future<List<Quote>> getAllQuotes() async {
    final response = await _supabase
        .from('quotes')
        .select('id, text, author')
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => Quote.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}

