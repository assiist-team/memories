import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memories/services/quotes_service.dart';

/// Widget that displays an inspirational quote
/// 
/// Shows a quote when there's available space, and can be hidden
/// when media/tags take up space.
class InspirationalQuote extends ConsumerWidget {
  final bool showQuote;

  const InspirationalQuote({
    super.key,
    this.showQuote = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quoteAsync = ref.watch(randomQuoteProvider);
    
    debugPrint('InspirationalQuote: Building widget. showQuote=$showQuote, quoteAsync=${quoteAsync.runtimeType}');

    if (!showQuote) {
      debugPrint('InspirationalQuote: Hidden because showQuote is false');
      return const SizedBox.shrink();
    }

    return quoteAsync.when(
      data: (quote) {
        debugPrint('InspirationalQuote: Data received. Quote is ${quote == null ? "null" : "not null"}');
        if (quote == null) {
          debugPrint('InspirationalQuote: No quote data available');
          return const SizedBox.shrink();
        }
        
        debugPrint('InspirationalQuote: Displaying quote: ${quote.text.substring(0, quote.text.length > 30 ? 30 : quote.text.length)}...');

        return Container(
          margin: const EdgeInsets.only(left: 5, right: 5, bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.format_quote,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      quote.text,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontStyle: FontStyle.italic,
                            height: 1.4,
                            fontSize: 15,
                          ),
                    ),
                  ),
                ],
              ),
              if (quote.author != null && quote.author!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '— ${quote.author}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
      loading: () {
        debugPrint('InspirationalQuote: Loading...');
        return const SizedBox.shrink(); // Don't show loading indicator
      },
      error: (error, stack) {
        // Log error for debugging but don't show to user
        debugPrint('InspirationalQuote: Error loading quote: $error');
        debugPrint('InspirationalQuote: Stack trace: $stack');
        return const SizedBox.shrink();
      },
    );
  }
}

/// Provider that fetches a random quote
/// 
/// Uses autoDispose to refresh each time the widget is built
/// This ensures a new quote is fetched when navigating to the capture screen
final randomQuoteProvider = FutureProvider.autoDispose<Quote?>((ref) async {
  debugPrint('randomQuoteProvider: Starting to fetch quote...');
  try {
    final quotesService = ref.watch(quotesServiceProvider);
    debugPrint('randomQuoteProvider: QuotesService obtained');
    final quote = await quotesService.getRandomQuote();
    debugPrint('randomQuoteProvider: Quote fetched: ${quote?.text.substring(0, quote.text.length > 30 ? 30 : quote.text.length) ?? "null"}...');
    return quote;
  } catch (e, stack) {
    debugPrint('randomQuoteProvider: Exception caught: $e');
    debugPrint('randomQuoteProvider: Stack: $stack');
    rethrow;
  }
});

