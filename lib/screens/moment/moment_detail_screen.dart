import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memories/providers/supabase_provider.dart';

/// Minimal moment detail screen
/// 
/// This is a placeholder implementation. A full detail view will be
/// implemented per the moment-detail-view spec.
class MomentDetailScreen extends ConsumerStatefulWidget {
  final String momentId;

  const MomentDetailScreen({
    super.key,
    required this.momentId,
  });

  @override
  ConsumerState<MomentDetailScreen> createState() => _MomentDetailScreenState();
}

class _MomentDetailScreenState extends ConsumerState<MomentDetailScreen> {
  Map<String, dynamic>? _moment;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMoment();
  }

  Future<void> _loadMoment() async {
    try {
      final supabase = ref.read(supabaseClientProvider);
      final response = await supabase
          .from('moments')
          .select()
          .eq('id', widget.momentId)
          .single();

      if (mounted) {
        setState(() {
          _moment = response;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Memory'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Error: $_error'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadMoment,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _moment == null
                  ? const Center(child: Text('Moment not found'))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _moment!['title'] ?? 'Untitled',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 16),
                          if (_moment!['text_description'] != null)
                            Text(
                              _moment!['text_description'],
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          const SizedBox(height: 16),
                          if (_moment!['raw_transcript'] != null) ...[
                            Text(
                              'Transcript:',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _moment!['raw_transcript'],
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (_moment!['tags'] != null &&
                              (_moment!['tags'] as List).isNotEmpty) ...[
                            Wrap(
                              spacing: 8,
                              children: (_moment!['tags'] as List)
                                  .map<Widget>((tag) => Chip(
                                        label: Text(tag.toString()),
                                      ))
                                  .toList(),
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (_moment!['photo_urls'] != null &&
                              (_moment!['photo_urls'] as List).isNotEmpty)
                            Text(
                              'Photos: ${(_moment!['photo_urls'] as List).length}',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          if (_moment!['video_urls'] != null &&
                              (_moment!['video_urls'] as List).isNotEmpty)
                            Text(
                              'Videos: ${(_moment!['video_urls'] as List).length}',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                        ],
                      ),
                    ),
    );
  }
}

