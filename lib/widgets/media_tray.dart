import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Widget for displaying and managing media attachments
///
/// Shows thumbnails for photos and videos with remove controls.
/// Displays helper text when limits are reached.
class MediaTray extends StatelessWidget {
  /// List of photo file paths
  final List<String> photoPaths;

  /// List of video file paths
  final List<String> videoPaths;

  /// Callback when a photo should be removed
  final ValueChanged<int> onPhotoRemoved;

  /// Callback when a video should be removed
  final ValueChanged<int> onVideoRemoved;

  /// Whether photo limit has been reached
  final bool canAddPhoto;

  /// Whether video limit has been reached
  final bool canAddVideo;

  const MediaTray({
    super.key,
    required this.photoPaths,
    required this.videoPaths,
    required this.onPhotoRemoved,
    required this.onVideoRemoved,
    required this.canAddPhoto,
    required this.canAddVideo,
  });

  @override
  Widget build(BuildContext context) {
    final hasMedia = photoPaths.isNotEmpty || videoPaths.isNotEmpty;

    if (!hasMedia) {
      return const SizedBox.shrink();
    }

    // Combine photos and videos into a single horizontal strip
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: photoPaths.length + videoPaths.length,
        itemBuilder: (context, index) {
          // Photos come first, then videos
          if (index < photoPaths.length) {
            return _MediaThumbnail(
              filePath: photoPaths[index],
              isVideo: false,
              onRemoved: () => onPhotoRemoved(index),
            );
          } else {
            final videoIndex = index - photoPaths.length;
            return _MediaThumbnail(
              filePath: videoPaths[videoIndex],
              isVideo: true,
              onRemoved: () => onVideoRemoved(videoIndex),
            );
          }
        },
      ),
    );
  }
}

class _MediaThumbnail extends StatefulWidget {
  final String filePath;
  final bool isVideo;
  final VoidCallback onRemoved;

  const _MediaThumbnail({
    required this.filePath,
    required this.isVideo,
    required this.onRemoved,
  });

  @override
  State<_MediaThumbnail> createState() => _MediaThumbnailState();
}

class _MediaThumbnailState extends State<_MediaThumbnail> {
  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    if (widget.isVideo) {
      _initializeVideo();
    }
  }

  Future<void> _initializeVideo() async {
    try {
      _videoController = VideoPlayerController.file(File(widget.filePath));
      await _videoController!.initialize();
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      // Handle error - show placeholder
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final overlayColor = theme.colorScheme.onSurface.withOpacity(0.7);
    final overlayBackgroundColor = theme.colorScheme.surface.withOpacity(0.8);

    return Container(
      width: 100,
      height: 100,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: theme.colorScheme.surfaceContainerHighest,
      ),
      child: Stack(
        children: [
          // Media preview
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: widget.isVideo ? _buildVideoPreview() : _buildPhotoPreview(),
          ),
          // Remove button
          Positioned(
            top: 4,
            right: 4,
            child: Semantics(
              label: 'Remove ${widget.isVideo ? 'video' : 'photo'}',
              button: true,
              child: Material(
                color: overlayBackgroundColor,
                shape: const CircleBorder(),
                child: IconButton(
                  icon: Icon(Icons.close, size: 18, color: overlayColor),
                  onPressed: widget.onRemoved,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
              ),
            ),
          ),
          // Video badge
          if (widget.isVideo)
            Positioned(
              bottom: 4,
              left: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: overlayBackgroundColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  Icons.play_circle_outline,
                  size: 16,
                  color: overlayColor,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPhotoPreview() {
    try {
      return Image.file(
        File(widget.filePath),
        fit: BoxFit.cover,
        width: 100,
        height: 100,
        errorBuilder: (context, error, stackTrace) {
          return const Center(
            child: Icon(Icons.broken_image),
          );
        },
      );
    } catch (e) {
      return const Center(
        child: Icon(Icons.broken_image),
      );
    }
  }

  Widget _buildVideoPreview() {
    if (_videoController == null || !_videoController!.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    return AspectRatio(
      aspectRatio: _videoController!.value.aspectRatio,
      child: VideoPlayer(_videoController!),
    );
  }
}
