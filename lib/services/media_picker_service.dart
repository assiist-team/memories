import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

/// Exception thrown when media picking fails
class MediaPickerException implements Exception {
  final String message;
  MediaPickerException(this.message);
  
  @override
  String toString() => message;
}

/// Service for picking media from camera or gallery
class MediaPickerService {
  final ImagePicker _imagePicker = ImagePicker();

  /// Pick a photo from camera
  Future<String?> pickPhotoFromCamera() async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
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
}

