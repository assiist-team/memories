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
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasMedia) ...[
          // Photos section
          if (photoPaths.isNotEmpty) ...[
            Text(
              'Photos (${photoPaths.length}/10)',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: photoPaths.length,
                itemBuilder: (context, index) {
                  return _MediaThumbnail(
                    filePath: photoPaths[index],
                    isVideo: false,
                    onRemoved: () => onPhotoRemoved(index),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
          // Videos section
          if (videoPaths.isNotEmpty) ...[
            Text(
              'Videos (${videoPaths.length}/3)',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: videoPaths.length,
                itemBuilder: (context, index) {
                  return _MediaThumbnail(
                    filePath: videoPaths[index],
                    isVideo: true,
                    onRemoved: () => onVideoRemoved(index),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ],
        // Helper text for limits
        if (!canAddPhoto || !canAddVideo)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _getLimitMessage(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
      ],
    );
  }

  String _getLimitMessage() {
    if (!canAddPhoto && !canAddVideo) {
      return 'Media limit reached (10 photos, 3 videos max)';
    } else if (!canAddPhoto) {
      return 'Photo limit reached (10 photos max)';
    } else {
      return 'Video limit reached (3 videos max)';
    }
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
    return Container(
      width: 100,
      height: 100,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Stack(
        children: [
          // Media preview
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: widget.isVideo
                ? _buildVideoPreview()
                : _buildPhotoPreview(),
          ),
          // Remove button
          Positioned(
            top: 4,
            right: 4,
            child: Semantics(
              label: 'Remove ${widget.isVideo ? 'video' : 'photo'}',
              button: true,
              child: Material(
                color: Colors.black54,
                shape: const CircleBorder(),
                child: IconButton(
                  icon: const Icon(Icons.close, size: 18, color: Colors.white),
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
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(
                  Icons.play_circle_outline,
                  size: 16,
                  color: Colors.white,
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

