import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:memories/providers/auth_state_provider.dart';
import 'package:memories/providers/biometric_provider.dart';
import 'package:memories/providers/supabase_provider.dart';
import 'package:memories/services/auth_error_handler.dart';

/// Screen for managing security settings including biometric authentication
///
/// Provides:
/// - Biometric authentication toggle
/// - Clear secure storage when biometrics are disabled
class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  bool _isLoading = false;
  bool? _biometricEnabled;
  bool? _biometricAvailable;
  String? _biometricTypeName;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadBiometricSettings();
  }

  Future<void> _loadBiometricSettings() async {
    final container = ProviderScope.containerOf(context);
    final secureStorage = container.read(secureStorageServiceProvider);
    final biometricService = container.read(biometricServiceProvider);
    final supabase = container.read(supabaseClientProvider);

    try {
      // Check if biometrics are available
      final available = await biometricService.isAvailable();
      final typeName = available
          ? await biometricService.getAvailableBiometricTypeName()
          : null;

      // Check current enabled state from secure storage
      final enabled = await secureStorage.isBiometricEnabled();

      // Also check from Supabase profile for consistency
      final user = supabase.auth.currentUser;
      if (user != null) {
        try {
          final profileResponse = await supabase
              .from('profiles')
              .select('biometric_enabled')
              .eq('id', user.id)
              .single();

          final profileEnabled =
              profileResponse['biometric_enabled'] as bool? ?? false;

          // Sync: if profile says enabled but secure storage doesn't, update secure storage
          if (profileEnabled && !enabled) {
            await secureStorage.setBiometricEnabled(true);
          }

          setState(() {
            _biometricEnabled = profileEnabled;
            _biometricAvailable = available;
            _biometricTypeName = typeName;
          });
          return;
        } catch (e) {
          // If profile fetch fails, use secure storage value
        }
      }

      setState(() {
        _biometricEnabled = enabled;
        _biometricAvailable = available;
        _biometricTypeName = typeName;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load biometric settings';
      });
    }
  }

  Future<void> _toggleBiometric(bool enabled) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final container = ProviderScope.containerOf(context);
      final secureStorage = container.read(secureStorageServiceProvider);
      final biometricService = container.read(biometricServiceProvider);
      final supabase = container.read(supabaseClientProvider);

      final user = supabase.auth.currentUser;
      if (user == null) {
        setState(() {
          _errorMessage = 'You must be signed in to change this setting';
          _isLoading = false;
        });
        return;
      }

      if (enabled) {
        // Enable biometrics: authenticate first, then update settings
        final authenticated = await biometricService.authenticate(
          reason:
              'Enable ${_biometricTypeName ?? 'biometric authentication'} for quick access',
        );

        if (!authenticated) {
          setState(() {
            _errorMessage =
                'Biometric authentication failed. Please try again.';
            _isLoading = false;
            _biometricEnabled = false;
          });
          return;
        }

        // Update Supabase profile
        await supabase
            .from('profiles')
            .update({'biometric_enabled': true}).eq('id', user.id);

        // Update secure storage
        await secureStorage.setBiometricEnabled(true);
      } else {
        // Disable biometrics: clear secure storage and update profile
        await secureStorage.clearBiometricPreference();
        await secureStorage.clearSession(); // Clear session as per requirements

        // Update Supabase profile
        await supabase
            .from('profiles')
            .update({'biometric_enabled': false}).eq('id', user.id);
      }

      setState(() {
        _biometricEnabled = enabled;
        _isLoading = false;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Security Settings'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Error message
              if (_errorMessage != null)
                Semantics(
                  label: 'Error message',
                  liveRegion: true,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
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

              // Biometric authentication section
              Semantics(
                label: 'Biometric authentication settings',
                header: true,
                child: Text(
                  'Biometric Authentication',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 8),

              if (_biometricAvailable == null)
                const Center(child: CircularProgressIndicator())
              else if (!_biometricAvailable!)
                Semantics(
                  label: 'Biometric authentication not available',
                  child: Text(
                    'Biometric authentication is not available on this device.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                )
              else ...[
                Semantics(
                  label: 'Biometric authentication toggle',
                  child: SwitchListTile(
                    title: Text(
                      'Enable ${_biometricTypeName ?? 'Biometric'} Authentication',
                    ),
                    subtitle: Text(
                      'Use ${_biometricTypeName ?? 'biometric authentication'} to quickly and securely sign in',
                    ),
                    value: _biometricEnabled ?? false,
                    onChanged:
                        _isLoading ? null : (value) => _toggleBiometric(value),
                    secondary: Icon(
                      _biometricTypeName?.toLowerCase().contains('face') ??
                              false
                          ? Icons.face
                          : Icons.fingerprint,
                    ),
                  ),
                ),
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.only(left: 16, top: 8),
                    child: SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
