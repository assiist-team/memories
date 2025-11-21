import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:gal/gal.dart';

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

  /// Saves a photo to the device photo library
  Future<void> _savePhotoToLibrary(String photoPath) async {
    try {
      await Gal.putImage(photoPath);
      debugPrint('[MediaPickerService] Photo saved to photo library: $photoPath');
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
      debugPrint('[MediaPickerService] Video saved to photo library: $videoPath');
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
}

