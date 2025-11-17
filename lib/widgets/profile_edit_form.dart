import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:memories/providers/supabase_provider.dart';
import 'package:memories/services/auth_error_handler.dart';

/// Widget for editing user profile name
/// 
/// Provides:
/// - Name edit field with validation (trim, non-empty)
/// - Updates Supabase profile table
/// - Success/error messaging
/// - Loading states during update
class ProfileEditForm extends StatefulWidget {
  const ProfileEditForm({super.key});

  @override
  State<ProfileEditForm> createState() => _ProfileEditFormState();
}

class _ProfileEditFormState extends State<ProfileEditForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _loadCurrentName();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentName() async {
    try {
      final container = ProviderScope.containerOf(context);
      final supabase = container.read(supabaseClientProvider);
      final user = supabase.auth.currentUser;

      if (user == null) {
        return;
      }

      final profileResponse = await supabase
          .from('profiles')
          .select('name')
          .eq('id', user.id)
          .single();

      final currentName = profileResponse['name'] as String? ?? '';
      _nameController.text = currentName;
    } catch (e) {
      // Profile might not exist yet, that's okay
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final container = ProviderScope.containerOf(context);
      final supabase = container.read(supabaseClientProvider);
      final user = supabase.auth.currentUser;

      if (user == null) {
        setState(() {
          _errorMessage = 'You must be signed in to update your profile';
          _isLoading = false;
        });
        return;
      }

      // Trim whitespace and update profile
      final trimmedName = _nameController.text.trim();
      
      await supabase
          .from('profiles')
          .update({'name': trimmedName})
          .eq('id', user.id);

      setState(() {
        _successMessage = 'Profile updated successfully';
        _isLoading = false;
      });

      // Clear success message after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _successMessage = null;
          });
        }
      });
    } catch (e) {
      final container = ProviderScope.containerOf(context);
      final errorHandler = container.read(authErrorHandlerProvider);
      setState(() {
        _errorMessage = errorHandler.handleAuthError(e);
        _isLoading = false;
      });
    }
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Name is required';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Name field
          Semantics(
            label: 'Name input field',
            textField: true,
            child: TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'Enter your name',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.done,
              validator: _validateName,
              enabled: !_isLoading,
              autofillHints: const [AutofillHints.name],
              onFieldSubmitted: (_) => _handleSave(),
            ),
          ),
          const SizedBox(height: 16),
          
          // Error message
          if (_errorMessage != null)
            Semantics(
              label: 'Error message',
              liveRegion: true,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ),
          
          // Success message
          if (_successMessage != null) ...[
            if (_errorMessage != null) const SizedBox(height: 8),
            Semantics(
              label: 'Success message',
              liveRegion: true,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _successMessage!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ),
          ],
          
          if (_errorMessage != null || _successMessage != null)
            const SizedBox(height: 16),
          
          // Save button
          Semantics(
            label: 'Save profile changes button',
            button: true,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleSave,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                minimumSize: const Size(0, 48),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ),
        ],
      ),
    );
  }
}

