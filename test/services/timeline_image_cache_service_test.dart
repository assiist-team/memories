import 'package:flutter_test/flutter_test.dart';
import 'package:memories/services/timeline_image_cache_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TimelineImageCacheService', () {
    test('returns signed url for storage path using compute invoker', () async {
      final calls = <String>[];
      final service = TimelineImageCacheService(
        isolateInvoker: (payload) async {
          calls.add('isolate:${payload['path']}');
          return 'signed://${payload['path']}';
        },
      );

      final result = await service.getSignedUrl(
        'https://example.supabase.co',
        'anon-key',
        'memories-photos',
        'users/42/photo.jpg',
      );

      expect(result, 'signed://users/42/photo.jpg');
      expect(calls, ['isolate:users/42/photo.jpg']);
    });

    test('normalizes full Supabase URL before requesting a signed url',
        () async {
      String? requestedPath;
      final service = TimelineImageCacheService(
        isolateInvoker: (payload) async {
          requestedPath = payload['path'] as String?;
          return 'signed://${payload['path']}';
        },
      );

      final result = await service.getSignedUrl(
        'https://example.supabase.co',
        'anon-key',
        'memories-photos',
        'https://example.supabase.co/storage/v1/object/public/'
            'memories-photos/uploads/2025/12/photo.jpg',
      );

      expect(result, 'signed://uploads/2025/12/photo.jpg');
      expect(requestedPath, 'uploads/2025/12/photo.jpg');
    });
  });
}
