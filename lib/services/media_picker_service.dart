import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:gal/gal.dart';
import 'package:file_picker/file_picker.dart';
import 'package:memories/services/plugin_audio_normalizer.dart';

/// Exception thrown when media picking fails
class MediaPickerException implements Exception {
  final String message;
  MediaPickerException(this.message);

  @override
  String toString() => message;
}

/// Result returned when an audio file is selected and normalized.
class PickedAudioFile {
  final String sourceFilePath;
  final PluginNormalizedAudio normalizedAudio;

  PickedAudioFile({
    required this.sourceFilePath,
    required this.normalizedAudio,
  });
}

/// Service for picking media from camera or gallery
class MediaPickerService {
  MediaPickerService({
    ImagePicker? imagePicker,
    PluginBackedAudioNormalizer? pluginAudioNormalizer,
    dynamic filePickerPlatform,
  })  : _imagePicker = imagePicker ?? ImagePicker(),
        _pluginAudioNormalizer =
            pluginAudioNormalizer ?? PluginBackedAudioNormalizer(),
        _filePicker = filePickerPlatform ?? FilePicker.platform;

  final ImagePicker _imagePicker;
  final PluginBackedAudioNormalizer _pluginAudioNormalizer;
  final dynamic _filePicker;

  /// Saves a photo to the device photo library
  Future<void> _savePhotoToLibrary(String photoPath) async {
    try {
      await Gal.putImage(photoPath);
      debugPrint(
          '[MediaPickerService] Photo saved to photo library: $photoPath');
    } catch (e) {
      // Log error but don't throw - saving to library is a convenience feature
      // and shouldn't prevent the app from using the captured photo
      debugPrint('[MediaPickerService] Failed to save photo to library: $e');
    }
  }

  /// Saves a video to the device photo library
  Future<void> _saveVideoToLibrary(String videoPath) async {
    try {
      await Gal.putVideo(videoPath);
      debugPrint(
          '[MediaPickerService] Video saved to photo library: $videoPath');
    } catch (e) {
      // Log error but don't throw - saving to library is a convenience feature
      // and shouldn't prevent the app from using the captured video
      debugPrint('[MediaPickerService] Failed to save video to library: $e');
    }
  }

  /// Pick a photo from camera
  Future<String?> pickPhotoFromCamera() async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      // Save to photo library if capture was successful
      if (photo != null) {
        await _savePhotoToLibrary(photo.path);
      }

      return photo?.path;
    } catch (e) {
      final errorMessage = e.toString().toLowerCase();

      // Check for permission-related errors
      if (errorMessage.contains('permission') ||
          errorMessage.contains('denied') ||
          errorMessage.contains('unauthorized')) {
        throw MediaPickerException(
          'Camera permission denied. Please grant camera access in Settings.',
        );
      }

      // Check for camera unavailable errors
      if (errorMessage.contains('unavailable') ||
          errorMessage.contains('not available') ||
          errorMessage.contains('no camera')) {
        throw MediaPickerException(
          'Camera unavailable. Please check if your device has a camera and try again.',
        );
      }

      // Generic error
      debugPrint('[MediaPickerService] Camera error: $e');
      throw MediaPickerException(
        'Failed to access camera. Please try again.',
      );
    }
  }

  /// Pick a photo from gallery
  Future<String?> pickPhotoFromGallery() async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      return photo?.path;
    } catch (e) {
      final errorMessage = e.toString().toLowerCase();

      // Check for permission-related errors
      if (errorMessage.contains('permission') ||
          errorMessage.contains('denied') ||
          errorMessage.contains('unauthorized')) {
        throw MediaPickerException(
          'Photo library permission denied. Please grant photo library access in Settings.',
        );
      }

      // Generic error
      debugPrint('[MediaPickerService] Gallery error: $e');
      throw MediaPickerException(
        'Failed to access photo library. Please try again.',
      );
    }
  }

  /// Pick a video from camera
  Future<String?> pickVideoFromCamera() async {
    try {
      final XFile? video = await _imagePicker.pickVideo(
        source: ImageSource.camera,
      );

      // Save to photo library if capture was successful
      if (video != null) {
        await _saveVideoToLibrary(video.path);
      }

      return video?.path;
    } catch (e) {
      final errorMessage = e.toString().toLowerCase();

      // Check for permission-related errors
      if (errorMessage.contains('permission') ||
          errorMessage.contains('denied') ||
          errorMessage.contains('unauthorized')) {
        throw MediaPickerException(
          'Camera permission denied. Please grant camera access in Settings.',
        );
      }

      // Check for camera unavailable errors
      if (errorMessage.contains('unavailable') ||
          errorMessage.contains('not available') ||
          errorMessage.contains('no camera')) {
        throw MediaPickerException(
          'Camera unavailable. Please check if your device has a camera and try again.',
        );
      }

      // Generic error
      debugPrint('[MediaPickerService] Camera video error: $e');
      throw MediaPickerException(
        'Failed to access camera. Please try again.',
      );
    }
  }

  /// Pick a video from gallery
  Future<String?> pickVideoFromGallery() async {
    try {
      final XFile? video = await _imagePicker.pickVideo(
        source: ImageSource.gallery,
      );
      return video?.path;
    } catch (e) {
      final errorMessage = e.toString().toLowerCase();

      // Check for permission-related errors
      if (errorMessage.contains('permission') ||
          errorMessage.contains('denied') ||
          errorMessage.contains('unauthorized')) {
        throw MediaPickerException(
          'Photo library permission denied. Please grant photo library access in Settings.',
        );
      }

      // Generic error
      debugPrint('[MediaPickerService] Gallery video error: $e');
      throw MediaPickerException(
        'Failed to access photo library. Please try again.',
      );
    }
  }

  /// Pick multiple photos from gallery
  Future<List<String>> pickMultiplePhotos() async {
    try {
      final List<XFile> photos = await _imagePicker.pickMultiImage(
        imageQuality: 85,
      );
      return photos.map((photo) => photo.path).toList();
    } catch (e) {
      final errorMessage = e.toString().toLowerCase();

      // Check for permission-related errors
      if (errorMessage.contains('permission') ||
          errorMessage.contains('denied') ||
          errorMessage.contains('unauthorized')) {
        throw MediaPickerException(
          'Photo library permission denied. Please grant photo library access in Settings.',
        );
      }

      // Generic error
      debugPrint('[MediaPickerService] Multi-image picker error: $e');
      throw MediaPickerException(
        'Failed to access photo library. Please try again.',
      );
    }
  }

  /// Supported audio file extensions for custom file type selection.
  /// These are primarily used on iOS where FileType.audio has UTI compatibility issues.
  static const List<String> _supportedAudioExtensions = [
    'mp3',
    'm4a',
    'wav',
    'aac',
    'flac',
    'ogg',
    'wma',
    'aiff',
    'caf',
  ];

  /// Pick an audio file from Files / storage and return its path.
  /// Returns null if the user cancels the selection.
  ///
  /// Platform-specific behavior:
  /// - iOS: Uses FileType.custom with explicit extensions due to UTI (Uniform Type Identifier)
  ///   quirks where FileType.audio may not reliably open the system picker.
  /// - Android/Other: Uses FileType.audio for a cleaner user experience (shows audio files by default).
  ///   This follows best practices when platform support is reliable.
  Future<String?> pickAudioFile() async {
    try {
      debugPrint('[MediaPickerService] Starting audio file picker');

      final result = await _pickAudioFileWithPlatformConfig();

      if (result == null || result.files.isEmpty) {
        return null; // User cancelled selection
      }

      final selectedFile = result.files.first;
      final path = selectedFile.path;

      if (path == null || path.isEmpty) {
        throw MediaPickerException(
          'Selected audio file is not accessible on this device.',
        );
      }

      final extension = path.split('.').last.toLowerCase();
      final platform = Platform.isIOS
          ? 'iOS'
          : Platform.isAndroid
              ? 'Android'
              : 'Other';
      debugPrint(
          '[MediaPickerService] Successfully picked audio file on $platform: .$extension');

      return path;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('[MediaPickerService] Audio picker error: $e');
        debugPrint('[MediaPickerService] Stack trace: $stackTrace');
      }

      // Provide user-friendly error messages
      final errorMessage = e.toString().toLowerCase();
      if (errorMessage.contains('permission') ||
          errorMessage.contains('denied') ||
          errorMessage.contains('unauthorized')) {
        throw MediaPickerException(
          'File access permission denied. Please grant file access in Settings.',
        );
      }

      throw MediaPickerException(
        'Failed to pick audio file. Please try again.',
      );
    }
  }

  /// Picks an audio file using platform-appropriate configuration.
  ///
  /// Isolates platform-specific file picker behavior to keep the main method clean.
  Future<FilePickerResult?> _pickAudioFileWithPlatformConfig() async {
    if (Platform.isIOS) {
      // iOS: Use FileType.custom with explicit extensions.
      // FileType.audio relies on UTIs which can be inconsistent on iOS,
      // causing the picker to fail to open. Explicit extensions ensure reliability.
      return await _filePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: _supportedAudioExtensions,
        allowCompression: false,
        allowMultiple: false,
        withData: false,
      );
    } else {
      // Android/Other: Use FileType.audio for better UX (shows audio files by default).
      // This is the recommended approach when platform support is reliable.
      // If FileType.audio doesn't work reliably on a specific platform,
      // switch to FileType.custom with _supportedAudioExtensions.
      return await _filePicker.pickFiles(
        type: FileType.audio,
        allowCompression: false,
        allowMultiple: false,
        withData: false,
      );
    }
  }

  /// Pick an audio file from Files / storage, normalize it, and return metadata.
  Future<PickedAudioFile?> pickAudioFromFiles() async {
    try {
      final path = await pickAudioFile();
      if (path == null) {
        return null; // User cancelled selection.
      }

      final normalizedAudio = await _pluginAudioNormalizer.normalize(path);

      return PickedAudioFile(
        sourceFilePath: path,
        normalizedAudio: normalizedAudio,
      );
    } on AudioNormalizationFailure {
      rethrow;
    } catch (e) {
      throw MediaPickerException(
        'Failed to import audio. Please try again. (${e.toString()})',
      );
    }
  }
}
