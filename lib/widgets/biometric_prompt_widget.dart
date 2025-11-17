import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:memories/providers/biometric_provider.dart';
import 'package:memories/providers/supabase_provider.dart';
import 'package:memories/services/biometric_service.dart';
import 'package:memories/services/secure_storage_service.dart';

/// Widget that prompts users to enable biometric authentication after first successful login
///
/// This widget:
/// - Shows a dialog after successful login
/// - Checks if biometrics are available
/// - Allows users to enable or skip biometric authentication
/// - Stores preference in both Supabase profiles table and secure storage
class BiometricPromptWidget {
  /// Show biometric prompt dialog after successful login
  ///
  /// Returns true if user enabled biometrics, false otherwise
  static Future<bool> showPrompt(
    BuildContext context, {
    required User user,
    required SecureStorageService secureStorage,
  }) async {
    final container = ProviderScope.containerOf(context);
    final biometricService = container.read(biometricServiceProvider);
    final supabase = container.read(supabaseClientProvider);

    // Check if biometrics are available
    final isAvailable = await biometricService.isAvailable();
    if (!isAvailable) {
      // Biometrics not available, don't show prompt
      return false;
    }

    // Check if user already has biometrics enabled
    final alreadyEnabled = await secureStorage.isBiometricEnabled();
    if (alreadyEnabled) {
      // Already enabled, don't show prompt
      return true;
    }

    // Get biometric type name for display
    final biometricTypeName =
        await biometricService.getAvailableBiometricTypeName();
    if (biometricTypeName == null) {
      return false;
    }

    // Show dialog
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _BiometricPromptDialog(
        biometricTypeName: biometricTypeName,
        user: user,
        supabase: supabase,
        secureStorage: secureStorage,
        biometricService: biometricService,
      ),
    );

    return result ?? false;
  }
}

class _BiometricPromptDialog extends StatefulWidget {
  final String biometricTypeName;
  final User user;
  final SupabaseClient supabase;
  final SecureStorageService secureStorage;
  final BiometricService biometricService;

  const _BiometricPromptDialog({
    required this.biometricTypeName,
    required this.user,
    required this.supabase,
    required this.secureStorage,
    required this.biometricService,
  });

  @override
  State<_BiometricPromptDialog> createState() => _BiometricPromptDialogState();
}

class _BiometricPromptDialogState extends State<_BiometricPromptDialog> {
  bool _isProcessing = false;
  String? _errorMessage;

  Future<void> _enableBiometrics() async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      // First, authenticate with biometrics to ensure they work
      final authenticated = await widget.biometricService.authenticate(
        reason:
            'Enable ${widget.biometricTypeName} for quick access to your account',
      );

      if (!authenticated) {
        setState(() {
          _errorMessage = 'Biometric authentication failed. Please try again.';
          _isProcessing = false;
        });
        return;
      }

      // Update profile in Supabase
      await widget.supabase
          .from('profiles')
          .update({'biometric_enabled': true}).eq('id', widget.user.id);

      // Store preference in secure storage
      await widget.secureStorage.setBiometricEnabled(true);

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to enable biometrics. Please try again later.';
        _isProcessing = false;
      });
    }
  }

  void _skipBiometrics() {
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Semantics(
        label: 'Enable ${widget.biometricTypeName}',
        header: true,
        child: Text('Enable ${widget.biometricTypeName}?'),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Use ${widget.biometricTypeName} to quickly and securely sign in to your account.',
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
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
          ],
        ],
      ),
      actions: [
        Semantics(
          label: 'Skip biometric authentication',
          button: true,
          child: TextButton(
            onPressed: _isProcessing ? null : _skipBiometrics,
            child: const Text('Skip'),
          ),
        ),
        Semantics(
          label: 'Enable ${widget.biometricTypeName}',
          button: true,
          child: ElevatedButton(
            onPressed: _isProcessing ? null : _enableBiometrics,
            child: _isProcessing
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text('Enable ${widget.biometricTypeName}'),
          ),
        ),
      ],
    );
  }
}
