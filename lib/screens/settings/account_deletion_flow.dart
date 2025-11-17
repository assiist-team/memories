import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:memories/providers/supabase_provider.dart';
import 'package:memories/providers/biometric_provider.dart';
import 'package:memories/providers/auth_state_provider.dart';
import 'package:memories/services/account_deletion_service.dart';

/// Multi-step account deletion flow
/// 
/// This flow requires:
/// 1. Warning screen with clear explanation of consequences
/// 2. Re-authentication (password or biometric)
/// 3. Final confirmation button
/// 
/// Security:
/// - Requires explicit confirmation at multiple steps
/// - Requires re-authentication before deletion
/// - All local data is cleared after successful deletion
class AccountDeletionFlow extends StatefulWidget {
  const AccountDeletionFlow({super.key});

  @override
  State<AccountDeletionFlow> createState() => _AccountDeletionFlowState();
}

enum DeletionStep {
  warning,
  reauthentication,
  finalConfirmation,
}

class _AccountDeletionFlowState extends State<AccountDeletionFlow> {
  DeletionStep _currentStep = DeletionStep.warning;
  bool _isLoading = false;
  String? _errorMessage;
  
  // Re-authentication form controllers
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _useBiometric = false;
  bool _biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    _checkBiometricAvailability();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _checkBiometricAvailability() async {
    final container = ProviderScope.containerOf(context);
    final biometricService = container.read(biometricServiceProvider);
    final isAvailable = await biometricService.isAvailable();
    
    setState(() {
      _biometricAvailable = isAvailable;
    });
  }

  Future<void> _handleReauthentication() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final container = ProviderScope.containerOf(context);
      final supabase = container.read(supabaseClientProvider);
      final secureStorage = container.read(secureStorageServiceProvider);
      final biometricService = container.read(biometricServiceProvider);
      
      final accountDeletionService = AccountDeletionService(
        supabase,
        secureStorage,
        biometricService,
      );

      final user = supabase.auth.currentUser;
      if (user == null) {
        setState(() {
          _errorMessage = 'You must be logged in to delete your account';
          _isLoading = false;
        });
        return;
      }

      bool authenticated = false;

      if (_useBiometric && _biometricAvailable) {
        authenticated = await accountDeletionService.reauthenticateWithBiometric();
      } else {
        if (_passwordController.text.isEmpty) {
          setState(() {
            _errorMessage = 'Please enter your password';
            _isLoading = false;
          });
          return;
        }

        authenticated = await accountDeletionService.reauthenticate(
          email: user.email ?? '',
          password: _passwordController.text,
        );
      }

      if (authenticated) {
        setState(() {
          _currentStep = DeletionStep.finalConfirmation;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = _useBiometric && _biometricAvailable
              ? 'Biometric authentication failed. Please try again or use password.'
              : 'Invalid password. Please try again.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Authentication failed: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleFinalDeletion() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final container = ProviderScope.containerOf(context);
      final supabase = container.read(supabaseClientProvider);
      final secureStorage = container.read(secureStorageServiceProvider);
      final biometricService = container.read(biometricServiceProvider);
      
      final accountDeletionService = AccountDeletionService(
        supabase,
        secureStorage,
        biometricService,
      );

      await accountDeletionService.deleteAccount();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your account has been deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Navigation will be handled by auth state provider
      // User will be automatically routed to auth stack
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to delete account: ${e.toString()}';
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete account: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _goToReauthentication() {
    setState(() {
      _currentStep = DeletionStep.reauthentication;
      _errorMessage = null;
    });
  }

  void _goBack() {
    if (_currentStep == DeletionStep.warning) {
      Navigator.of(context).pop();
    } else if (_currentStep == DeletionStep.reauthentication) {
      setState(() {
        _currentStep = DeletionStep.warning;
        _errorMessage = null;
        _passwordController.clear();
      });
    } else {
      setState(() {
        _currentStep = DeletionStep.reauthentication;
        _errorMessage = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Delete Account'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_currentStep == DeletionStep.warning) _buildWarningStep(),
              if (_currentStep == DeletionStep.reauthentication)
                _buildReauthenticationStep(),
              if (_currentStep == DeletionStep.finalConfirmation)
                _buildFinalConfirmationStep(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWarningStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: 'Warning icon',
          child: Icon(
            Icons.warning_amber_rounded,
            size: 64,
            color: Theme.of(context).colorScheme.error,
          ),
        ),
        const SizedBox(height: 24),
        Semantics(
          header: true,
          child: Text(
            'Delete Your Account',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        const SizedBox(height: 16),
        Semantics(
          label: 'Account deletion warning information',
          child: Text(
            'This action cannot be undone. Deleting your account will permanently:',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
        const SizedBox(height: 16),
        Semantics(
          label: 'Consequences list',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildConsequenceItem('Remove all your personal data'),
              _buildConsequenceItem('Delete all your memories and stories'),
              _buildConsequenceItem('Cancel all active subscriptions'),
              _buildConsequenceItem('Remove your profile and account information'),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Semantics(
          label: 'Continue to account deletion',
          button: true,
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _goToReauthentication,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
                padding: const EdgeInsets.symmetric(vertical: 16),
                minimumSize: const Size(0, 48),
              ),
              child: const Text('Continue'),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Semantics(
          label: 'Cancel account deletion',
          button: true,
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                minimumSize: const Size(0, 48),
              ),
              child: const Text('Cancel'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConsequenceItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            label: 'Warning indicator',
            child: Icon(
              Icons.remove_circle_outline,
              size: 20,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReauthenticationStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            'Confirm Your Identity',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
        const SizedBox(height: 8),
        Semantics(
          label: 'Re-authentication explanation',
          child: Text(
            'For your security, please confirm your identity before deleting your account.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        const SizedBox(height: 24),
        if (_biometricAvailable) ...[
          Semantics(
            label: 'Use biometric authentication',
            button: true,
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isLoading
                    ? null
                    : () {
                        setState(() {
                          _useBiometric = true;
                        });
                        _handleReauthentication();
                      },
                icon: const Icon(Icons.fingerprint),
                label: Text(
                  'Use ${_biometricAvailable ? 'Biometric' : 'Password'} Authentication',
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  minimumSize: const Size(0, 48),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: Divider(color: Theme.of(context).dividerColor)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  'OR',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              Expanded(child: Divider(color: Theme.of(context).dividerColor)),
            ],
          ),
          const SizedBox(height: 16),
        ],
        Semantics(
          label: 'Password input field',
          textField: true,
          child: TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            enabled: !_isLoading,
            decoration: InputDecoration(
              labelText: 'Password',
              hintText: 'Enter your password',
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
              errorText: _errorMessage,
            ),
            onFieldSubmitted: (_) => _handleReauthentication(),
          ),
        ),
        const SizedBox(height: 24),
        if (_errorMessage != null)
          Semantics(
            label: 'Error message',
            liveRegion: true,
            child: Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (_errorMessage != null) const SizedBox(height: 16),
        Semantics(
          label: 'Confirm identity',
          button: true,
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleReauthentication,
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
                  : const Text('Confirm Identity'),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Semantics(
          label: 'Go back',
          button: true,
          child: SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: _isLoading ? null : _goBack,
              child: const Text('Back'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFinalConfirmationStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            'Final Confirmation',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        const SizedBox(height: 16),
        Semantics(
          label: 'Final warning',
          child: Text(
            'Are you absolutely sure you want to delete your account? This action is permanent and cannot be undone.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
        const SizedBox(height: 24),
        if (_errorMessage != null)
          Semantics(
            label: 'Error message',
            liveRegion: true,
            child: Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (_errorMessage != null) const SizedBox(height: 16),
        Semantics(
          label: 'Delete account permanently',
          button: true,
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleFinalDeletion,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
                padding: const EdgeInsets.symmetric(vertical: 16),
                minimumSize: const Size(0, 48),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Delete Account Permanently'),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Semantics(
          label: 'Cancel deletion',
          button: true,
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _isLoading ? null : _goBack,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                minimumSize: const Size(0, 48),
              ),
              child: const Text('Cancel'),
            ),
          ),
        ),
      ],
    );
  }
}

