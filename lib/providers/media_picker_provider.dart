import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:memories/services/media_picker_service.dart';

part 'media_picker_provider.g.dart';

/// Provider for media picker service
@riverpod
MediaPickerService mediaPickerService(MediaPickerServiceRef ref) {
  return MediaPickerService();
}

