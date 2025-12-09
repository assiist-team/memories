import 'package:flutter_dictation/flutter_dictation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:memories/services/plugin_audio_normalizer.dart';

class _MockNativeDictationService extends Mock
    implements NativeDictationService {}

void main() {
  late _MockNativeDictationService nativeService;
  late PluginBackedAudioNormalizer normalizer;

  setUp(() {
    nativeService = _MockNativeDictationService();
    normalizer = PluginBackedAudioNormalizer(
      nativeDictationService: nativeService,
    );
  });

  test('normalize returns DTO mapped to plugin result', () async {
    final pluginResult = NormalizedAudioResult(
      canonicalPath: '/tmp/canonical.m4a',
      duration: const Duration(minutes: 1, seconds: 30),
      sizeBytes: 8 * 1024 * 1024,
      wasReencoded: true,
    );

    when(() => nativeService.normalizeAudio(any()))
        .thenAnswer((_) async => pluginResult);

    final normalized = await normalizer.normalize('/tmp/source.wav');

    expect(normalized.canonicalPath, equals(pluginResult.canonicalPath));
    expect(normalized.durationSeconds, closeTo(90.0, 0.01));
    expect(normalized.fileSizeBytes, equals(pluginResult.sizeBytes));
    expect(normalized.wasReencoded, equals(pluginResult.wasReencoded));
  });

  test('normalize throws when plugin returns oversized file', () async {
    final pluginResult = NormalizedAudioResult(
      canonicalPath: '/tmp/canonical.m4a',
      duration: Duration.zero,
      sizeBytes: PluginBackedAudioNormalizer.maxFileSizeBytes + 1,
      wasReencoded: true,
    );

    when(() => nativeService.normalizeAudio(any()))
        .thenAnswer((_) async => pluginResult);

    await expectLater(
      normalizer.normalize('/tmp/source.wav'),
      throwsA(isA<AudioTooLargeException>()),
    );
  });
}
