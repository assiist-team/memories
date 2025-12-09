import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:memories/services/media_picker_service.dart';
import 'package:memories/services/plugin_audio_normalizer.dart';

part 'media_picker_provider.g.dart';

/// Provider for media picker service
@riverpod
MediaPickerService mediaPickerService(MediaPickerServiceRef ref) {
  final pluginNormalizer = ref.read(pluginAudioNormalizerProvider);
  return MediaPickerService(pluginAudioNormalizer: pluginNormalizer);
}
