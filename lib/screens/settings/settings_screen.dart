import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:memories/providers/supabase_provider.dart';
import 'package:memories/providers/auth_state_provider.dart';
import 'package:memories/services/logout_service.dart';
import 'package:memories/widgets/profile_edit_form.dart';
import 'package:memories/widgets/password_change_widget.dart';
import 'package:memories/widgets/user_info_display.dart';
import 'package:memories/screens/settings/security_settings_screen.dart';
import 'package:memories/screens/settings/account_deletion_flow.dart';

/// Screen for managing user settings and profile
/// 
/// Provides:
/// - Account section: Profile editing, user info display
/// - Security section: Password change, security settings
/// - Support section: Placeholder links
/// - Logout functionality
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _navigateToSecuritySettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SecuritySettingsScreen(),
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      final container = ProviderScope.containerOf(context);
      final supabase = container.read(supabaseClientProvider);
      final secureStorage = container.read(secureStorageServiceProvider);
      
      final logoutService = LogoutService(supabase, secureStorage);
      await logoutService.logout();
      
      // Navigation will be handled by auth state provider
      // User will be routed to auth stack automatically
    } catch (e) {
      // Show error if logout fails
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to sign out: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Account Section
              Semantics(
                label: 'Account settings section',
                header: true,
                child: Text(
                  'Account',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 16),
              
              // User Info Display
              const UserInfoDisplay(),
              const SizedBox(height: 24),
              
              // Profile Edit Form
              Semantics(
                label: 'Profile editing section',
                header: true,
                child: Text(
                  'Edit Profile',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: 16),
              const ProfileEditForm(),
              const SizedBox(height: 32),
              
              // Security Section
              Semantics(
                label: 'Security settings section',
                header: true,
                child: Text(
                  'Security',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 16),
              
              // Security Settings Link
              Semantics(
                label: 'Navigate to security settings',
                button: true,
                child: ListTile(
                  leading: const Icon(Icons.security),
                  title: const Text('Security Settings'),
                  subtitle: const Text('Manage biometric authentication'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _navigateToSecuritySettings(context),
                ),
              ),
              const SizedBox(height: 16),
              
              // Password Change
              Semantics(
                label: 'Password change section',
                header: true,
                child: Text(
                  'Change Password',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: 16),
              const PasswordChangeWidget(),
              const SizedBox(height: 32),
              
              // Support Section
              Semantics(
                label: 'Support section',
                header: true,
                child: Text(
                  'Support',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 16),
              
              // Placeholder support links
              Semantics(
                label: 'Help and support',
                button: true,
                child: ListTile(
                  leading: const Icon(Icons.help_outline),
                  title: const Text('Help & Support'),
                  subtitle: const Text('Get help with your account'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Help & Support coming soon'),
                      ),
                    );
                  },
                ),
              ),
              Semantics(
                label: 'Privacy policy',
                button: true,
                child: ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('Privacy Policy'),
                  subtitle: const Text('View our privacy policy'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Privacy Policy coming soon'),
                      ),
                    );
                  },
                ),
              ),
              Semantics(
                label: 'Terms of service',
                button: true,
                child: ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('Terms of Service'),
                  subtitle: const Text('View our terms of service'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Terms of Service coming soon'),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 32),
              
              // Account Deletion Section
              Semantics(
                label: 'Account deletion section',
                header: true,
                child: Text(
                  'Danger Zone',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                ),
              ),
              const SizedBox(height: 16),
              
              Semantics(
                label: 'Delete account',
                button: true,
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const AccountDeletionFlow(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.delete_forever),
                    label: const Text('Delete Account'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      minimumSize: const Size(0, 48),
                      foregroundColor: Theme.of(context).colorScheme.error,
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              
              // Logout Button
              Semantics(
                label: 'Sign out button',
                button: true,
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _handleLogout(context),
                    icon: const Icon(Icons.logout),
                    label: const Text('Sign Out'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      minimumSize: const Size(0, 48),
                      foregroundColor: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

