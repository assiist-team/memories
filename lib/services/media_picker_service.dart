import 'package:image_picker/image_picker.dart';

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
      return null;
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
      return null;
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
      return null;
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
      return null;
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
      return [];
    }
  }
}

