import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:memories/models/memory_type.dart';
import 'package:memories/models/queued_moment.dart';
import 'package:memories/providers/capture_state_provider.dart';
import 'package:memories/providers/media_picker_provider.dart';
import 'package:memories/providers/queue_status_provider.dart';
import 'package:memories/providers/supabase_provider.dart';
import 'package:memories/services/moment_save_service.dart';
import 'package:memories/services/moment_sync_service.dart';
import 'package:memories/services/offline_queue_service.dart';
import 'package:memories/screens/moment/moment_detail_screen.dart';
import 'package:memories/widgets/media_tray.dart';
import 'package:memories/widgets/queue_status_chips.dart';
import 'package:memories/widgets/tag_chip_input.dart';

/// Unified capture screen for creating Moments, Stories, and Mementos
/// 
/// Provides:
/// - Memory type toggles (Moment/Story/Memento)
/// - Dictation controls
/// - Optional description input
/// - Media attachment (photos/videos)
/// - Tagging
/// - Save/Cancel actions
class CaptureScreen extends ConsumerStatefulWidget {
  const CaptureScreen({super.key});

  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends ConsumerState<CaptureScreen> {
  final _descriptionController = TextEditingController();
  bool _isSaving = false;
  String? _saveProgressMessage;
  double? _saveProgress;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _handleAddPhoto() async {
    final mediaPicker = ref.read(mediaPickerServiceProvider);
    final notifier = ref.read(captureStateNotifierProvider.notifier);
    
    // Show dialog to choose camera or gallery
    final source = await showDialog<ImageSource?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Photo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final path = source == ImageSource.camera
        ? await mediaPicker.pickPhotoFromCamera()
        : await mediaPicker.pickPhotoFromGallery();

    if (path != null && mounted) {
      notifier.addPhoto(path);
    }
  }

  Future<void> _handleAddVideo() async {
    final mediaPicker = ref.read(mediaPickerServiceProvider);
    final notifier = ref.read(captureStateNotifierProvider.notifier);
    
    // Show dialog to choose camera or gallery
    final source = await showDialog<ImageSource?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Video'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.videocam),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.video_library),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final path = source == ImageSource.camera
        ? await mediaPicker.pickVideoFromCamera()
        : await mediaPicker.pickVideoFromGallery();

    if (path != null && mounted) {
      notifier.addVideo(path);
    }
  }

  Future<void> _handleSave() async {
    final state = ref.read(captureStateNotifierProvider);
    final notifier = ref.read(captureStateNotifierProvider.notifier);
    
    if (!state.canSave) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one item (transcript, media, or tag)'),
        ),
      );
      return;
    }

    if (_isSaving) {
      return; // Prevent double-save
    }

    setState(() {
      _isSaving = true;
      _saveProgress = 0.0;
      _saveProgressMessage = 'Preparing...';
    });

    try {
      // Step 1: Capture location metadata
      _saveProgressMessage = 'Capturing location...';
      _saveProgress = 0.05;
      setState(() {});
      
      await notifier.captureLocation();
      final updatedState = ref.read(captureStateNotifierProvider);
      
      // Step 2: Set captured timestamp
      final capturedAt = DateTime.now();
      notifier.setCapturedAt(capturedAt);

      // Step 3: Save moment with progress updates (or queue if offline)
      final saveService = ref.read(momentSaveServiceProvider);
      final queueService = ref.read(offlineQueueServiceProvider);
      MomentSaveResult? result;
      
      try {
        result = await saveService.saveMoment(
          state: updatedState,
          onProgress: ({message, progress}) {
            if (mounted) {
              setState(() {
                _saveProgressMessage = message;
                _saveProgress = progress;
              });
            }
          },
        );
      } on OfflineException {
        // Queue for offline sync
        final localId = OfflineQueueService.generateLocalId();
        final queuedMoment = QueuedMoment.fromCaptureState(
          localId: localId,
          state: updatedState,
          capturedAt: capturedAt,
        );
        await queueService.enqueue(queuedMoment);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Memory queued for sync when connection is restored'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
          notifier.clear();
          Navigator.of(context).pop();
          return;
        }
      }

      if (result == null) return; // Should not happen, but safety check

      // Step 4: Show title edit dialog if title was generated
      
      if (mounted && result.generatedTitle != null) {
        final editedTitle = await _showTitleEditDialog(result.generatedTitle!);
        
        // Update title if it was edited
        if (editedTitle != null && editedTitle != result.generatedTitle) {
          final supabase = ref.read(supabaseClientProvider);
          await supabase
              .from('moments')
              .update({'title': editedTitle})
              .eq('id', result.momentId);
        }
      }

      // Step 5: Show success message and navigate to detail view
      if (mounted) {
        final mediaCount = result.photoUrls.length + result.videoUrls.length;
        final locationText = result.hasLocation ? ' with location' : '';
        final mediaText = mediaCount > 0 ? ' ($mediaCount ${mediaCount == 1 ? 'item' : 'items'})' : '';
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Memory saved$locationText$mediaText'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );

        // Clear state and navigate to detail view
        notifier.clear();
        Navigator.of(context).pop();
        // Navigate to moment detail view
        final savedMomentId = result.momentId;
        if (savedMomentId.isNotEmpty) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => MomentDetailScreen(momentId: savedMomentId),
            ),
          );
        }
      }
    } on OfflineException {
      // Already handled above, but catch here to prevent generic error
      return;
    } on StorageQuotaException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    } on NetworkException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _handleSave(),
            ),
          ),
        );
      }
    } on PermissionException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _handleSave(),
            ),
          ),
        );
      }
      notifier.setError(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _saveProgressMessage = null;
          _saveProgress = null;
        });
      }
    }
  }

  Future<String?> _showTitleEditDialog(String initialTitle) async {
    final titleController = TextEditingController(text: initialTitle);
    
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Title'),
        content: TextField(
          controller: titleController,
          decoration: const InputDecoration(
            hintText: 'Enter title',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          maxLength: 60,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, initialTitle),
            child: const Text('Keep Original'),
          ),
          TextButton(
            onPressed: () {
              final edited = titleController.text.trim();
              Navigator.pop(
                context,
                edited.isEmpty ? initialTitle : edited,
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<bool> _handleCancel() async {
    final state = ref.read(captureStateNotifierProvider);
    
    if (state.hasUnsavedChanges) {
      final shouldDiscard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Discard changes?'),
          content: const Text('You have unsaved changes. Are you sure you want to discard them?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep Editing'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Discard'),
            ),
          ],
        ),
      );

      if (shouldDiscard == true) {
        ref.read(captureStateNotifierProvider.notifier).clear();
        return true;
      }
      return false;
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.read(captureStateNotifierProvider);
    final notifier = ref.read(captureStateNotifierProvider.notifier);

    return WillPopScope(
      onWillPop: _handleCancel,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Capture Memory'),
          actions: [
            // Sync now action (in overflow menu)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) async {
                if (value == 'sync_now') {
                  await _handleSyncNow(ref);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'sync_now',
                  child: Row(
                    children: [
                      Icon(Icons.sync, size: 20),
                      SizedBox(width: 8),
                      Text('Sync Now'),
                    ],
                  ),
                ),
              ],
            ),
            // Cancel button
            TextButton(
              onPressed: () async {
                if (await _handleCancel()) {
                  if (mounted) {
                    Navigator.of(context).pop();
                  }
                }
              },
              child: const Text('Cancel'),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Queue status chips
              const QueueStatusChips(),
              // Main content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Memory type toggles
                _MemoryTypeToggle(
                  selectedType: state.memoryType,
                  onTypeChanged: (type) => notifier.setMemoryType(type),
                ),
                const SizedBox(height: 24),
                
                // Dictation control
                _DictationControl(
                  isDictating: state.isDictating,
                  transcript: state.rawTranscript ?? '',
                  onStart: () => notifier.startDictation(),
                  onStop: () => notifier.stopDictation(),
                ),
                const SizedBox(height: 24),
                
                // Description input
                Semantics(
                  label: 'Description input',
                  textField: true,
                  child: TextField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description (optional)',
                      hintText: 'Add any additional details...',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 4,
                    onChanged: (value) => notifier.updateDescription(value.isEmpty ? null : value),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Media tray
                MediaTray(
                  photoPaths: state.photoPaths,
                  videoPaths: state.videoPaths,
                  onPhotoRemoved: (index) => notifier.removePhoto(index),
                  onVideoRemoved: (index) => notifier.removeVideo(index),
                  canAddPhoto: state.canAddPhoto,
                  canAddVideo: state.canAddVideo,
                ),
                const SizedBox(height: 16),
                
                // Media add buttons
                Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        label: 'Add photo',
                        button: true,
                        child: OutlinedButton.icon(
                          onPressed: state.canAddPhoto ? _handleAddPhoto : null,
                          icon: const Icon(Icons.photo_camera),
                          label: const Text('Photo'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Semantics(
                        label: 'Add video',
                        button: true,
                        child: OutlinedButton.icon(
                          onPressed: state.canAddVideo ? _handleAddVideo : null,
                          icon: const Icon(Icons.videocam),
                          label: const Text('Video'),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Tagging input
                TagChipInput(
                  tags: state.tags,
                  onTagAdded: (tag) => notifier.addTag(tag),
                  onTagRemoved: (index) => notifier.removeTag(index),
                  hintText: 'Add tags (optional)',
                ),
                const SizedBox(height: 32),
                
                // Save button with progress indicator
                Semantics(
                  label: 'Save memory',
                  button: true,
                  child: ElevatedButton(
                    onPressed: (state.canSave && !_isSaving) ? _handleSave : null,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      minimumSize: const Size(0, 48),
                    ),
                    child: _isSaving
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              ),
                              if (_saveProgressMessage != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  _saveProgressMessage!,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                              if (_saveProgress != null) ...[
                                const SizedBox(height: 4),
                                LinearProgressIndicator(
                                  value: _saveProgress,
                                  backgroundColor: Colors.white.withOpacity(0.3),
                                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              ],
                            ],
                          )
                        : const Text('Save'),
                  ),
                ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleSyncNow(WidgetRef ref) async {
    final syncService = ref.read(momentSyncServiceProvider);
    
    try {
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 16),
                Text('Syncing queued moments...'),
              ],
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }
      
      // Trigger sync
      await syncService.syncQueuedMoments();
      
      // Invalidate queue status to refresh
      ref.invalidate(queueStatusProvider);
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sync completed'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}

class _MemoryTypeToggle extends StatelessWidget {
  final MemoryType selectedType;
  final ValueChanged<MemoryType> onTypeChanged;

  const _MemoryTypeToggle({
    required this.selectedType,
    required this.onTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<MemoryType>(
      segments: [
        ButtonSegment<MemoryType>(
          value: MemoryType.moment,
          label: Text(MemoryType.moment.displayName),
          icon: const Icon(Icons.access_time),
        ),
        ButtonSegment<MemoryType>(
          value: MemoryType.story,
          label: Text(MemoryType.story.displayName),
          icon: const Icon(Icons.book),
        ),
        ButtonSegment<MemoryType>(
          value: MemoryType.memento,
          label: Text(MemoryType.memento.displayName),
          icon: const Icon(Icons.inventory_2),
        ),
      ],
      selected: {selectedType},
      onSelectionChanged: (Set<MemoryType> selection) {
        if (selection.isNotEmpty) {
          onTypeChanged(selection.first);
        }
      },
    );
  }
}

class _DictationControl extends StatelessWidget {
  final bool isDictating;
  final String transcript;
  final VoidCallback onStart;
  final VoidCallback onStop;

  const _DictationControl({
    required this.isDictating,
    required this.transcript,
    required this.onStart,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Microphone button
        Semantics(
          label: isDictating ? 'Stop dictation' : 'Start dictation',
          button: true,
          child: Center(
            child: GestureDetector(
              onTapDown: (_) => onStart(),
              onTapUp: (_) => onStop(),
              onTapCancel: onStop,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDictating
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.primary,
                ),
                child: Icon(
                  isDictating ? Icons.stop : Icons.mic,
                  size: 40,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Transcript display
        if (transcript.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Semantics(
              label: 'Dictation transcript',
              liveRegion: true,
              child: Text(
                transcript,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ),
        if (transcript.isEmpty && !isDictating)
          Text(
            'Tap and hold the microphone to start dictating',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
      ],
    );
  }
}

