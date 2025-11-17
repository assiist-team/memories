import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Widget for inputting tags as chips
/// 
/// Provides a keyboard-friendly interface for adding tags.
/// Tags are case-insensitive and trimmed.
class TagChipInput extends StatefulWidget {
  /// Callback when a tag is added
  final ValueChanged<String> onTagAdded;
  
  /// Callback when a tag is removed
  final ValueChanged<int> onTagRemoved;
  
  /// Current list of tags
  final List<String> tags;
  
  /// Hint text for the input field
  final String? hintText;

  const TagChipInput({
    super.key,
    required this.onTagAdded,
    required this.onTagRemoved,
    required this.tags,
    this.hintText,
  });

  @override
  State<TagChipInput> createState() => _TagChipInputState();
}

class _TagChipInputState extends State<TagChipInput> {
  final _textController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleSubmitted(String value) {
    final trimmed = value.trim();
    if (trimmed.isNotEmpty) {
      widget.onTagAdded(trimmed);
      _textController.clear();
    }
  }

  void _handleChanged(String value) {
    // Add tag when comma or semicolon is entered
    if (value.contains(',') || value.contains(';')) {
      final parts = value.split(RegExp(r'[,;]'));
      if (parts.isNotEmpty) {
        final tag = parts.first.trim();
        if (tag.isNotEmpty) {
          widget.onTagAdded(tag);
        }
        _textController.text = parts.length > 1 ? parts.sublist(1).join(',') : '';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Tag input',
      textField: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Display existing tags as chips
          if (widget.tags.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (int i = 0; i < widget.tags.length; i++)
                  _TagChip(
                    label: widget.tags[i],
                    onRemoved: () => widget.onTagRemoved(i),
                  ),
              ],
            ),
          if (widget.tags.isNotEmpty) const SizedBox(height: 8),
          // Input field
          TextField(
            controller: _textController,
            focusNode: _focusNode,
            decoration: InputDecoration(
              hintText: widget.hintText ?? 'Add tags (press Enter or comma)',
              border: const OutlineInputBorder(),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: _handleSubmitted,
            onChanged: _handleChanged,
            inputFormatters: [
              // Prevent newlines
              FilteringTextInputFormatter.singleLineFormatter,
            ],
          ),
        ],
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemoved;

  const _TagChip({
    required this.label,
    required this.onRemoved,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Tag: $label',
      button: true,
      child: InputChip(
        label: Text(label),
        onDeleted: onRemoved,
        deleteIcon: const Icon(Icons.close, size: 18),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

