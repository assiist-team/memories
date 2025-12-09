import 'dart:io';

import 'package:flutter_dictation/flutter_dictation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'plugin_audio_normalizer.g.dart';

/// Base error thrown when plugin normalization fails in a user-visible way.
class AudioNormalizationFailure implements Exception {
  /// User-facing message describing the failure.
  final String message;

  const AudioNormalizationFailure(this.message);

  @override
  String toString() => 'AudioNormalizationFailure: $message';
}

/// Thrown when normalized audio still exceeds the allowed 50 MB limit.
class AudioTooLargeException extends AudioNormalizationFailure {
  /// Size of the normalized file in bytes.
  final int fileSizeBytes;

  AudioTooLargeException(this.fileSizeBytes)
      : super(
          'Audio is ${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB, which exceeds the 50 MB upload limit. Please record or import a shorter audio clip.',
        );
}

/// DTO that mirrors the plugin's normalization result but keeps the app decoupled.
class PluginNormalizedAudio {
  /// Canonical path returned by the plugin.
  final String canonicalPath;

  /// Duration of the normalized audio (seconds).
  final double durationSeconds;

  /// File size in bytes.
  final int fileSizeBytes;

  /// Whether the plugin re-encoded the source file.
  final bool wasReencoded;

  const PluginNormalizedAudio({
    required this.canonicalPath,
    required this.durationSeconds,
    required this.fileSizeBytes,
    required this.wasReencoded,
  });
}

@riverpod
PluginBackedAudioNormalizer pluginAudioNormalizer(
    PluginAudioNormalizerRef ref) {
  return PluginBackedAudioNormalizer();
}

/// Wraps [NativeDictationService.normalizeAudio] and enforces app limits.
class PluginBackedAudioNormalizer {
  static const int maxFileSizeBytes = 50 * 1024 * 1024;

  /// The native dictation service used to normalize audio files.
  final NativeDictationService _nativeDictationService;

  PluginBackedAudioNormalizer({
    NativeDictationService? nativeDictationService,
  }) : _nativeDictationService =
            nativeDictationService ?? NativeDictationService();

  /// Normalizes [sourcePath] and returns app-friendly DTO.
  Future<PluginNormalizedAudio> normalize(String sourcePath) async {
    final result = await _nativeDictationService.normalizeAudio(sourcePath);

    if (result.sizeBytes > maxFileSizeBytes) {
      throw AudioTooLargeException(result.sizeBytes);
    }

    final durationSeconds = result.duration.inMilliseconds / 1000.0;

    return PluginNormalizedAudio(
      canonicalPath: result.canonicalPath,
      durationSeconds: durationSeconds,
      fileSizeBytes: result.sizeBytes,
      wasReencoded: result.wasReencoded,
    );
  }

  /// Deletes a normalized file if it still exists.
  Future<void> cleanupNormalizedFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return;
    }

    try {
      await file.delete();
    } catch (_) {
      // Ignore cleanup failures.
    }
  }
}
