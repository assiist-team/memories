import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:memories/providers/supabase_provider.dart';

/// Widget for displaying read-only user information
/// 
/// Shows:
/// - Email address (from auth.users)
/// - Last sign-in timestamp
/// - Profile name (from profiles table)
/// - Account creation date (optional)
class UserInfoDisplay extends StatefulWidget {
  const UserInfoDisplay({super.key});

  @override
  State<UserInfoDisplay> createState() => _UserInfoDisplayState();
}

class _UserInfoDisplayState extends State<UserInfoDisplay> {
  String? _profileName;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadProfileInfo();
  }

  Future<void> _loadProfileInfo() async {
    try {
      final container = ProviderScope.containerOf(context);
      final supabase = container.read(supabaseClientProvider);
      final user = supabase.auth.currentUser;

      if (user == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Fetch profile name from profiles table
      try {
        final profileResponse = await supabase
            .from('profiles')
            .select('name')
            .eq('id', user.id)
            .single();

        setState(() {
          _profileName = profileResponse['name'] as String?;
          _isLoading = false;
        });
      } catch (e) {
        // Profile might not exist yet, that's okay
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load profile information';
        _isLoading = false;
      });
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Never';
    
    try {
      final date = DateTime.parse(dateString);
      return '${date.month}/${date.day}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    final container = ProviderScope.containerOf(context);
    final supabase = container.read(supabaseClientProvider);
    final user = supabase.auth.currentUser;

    if (user == null) {
      return Semantics(
        label: 'User information not available',
        child: Text(
          'Not signed in',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      );
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Semantics(
        label: 'Error loading user information',
        liveRegion: true,
        child: Text(
          _errorMessage!,
          style: TextStyle(
            color: Theme.of(context).colorScheme.error,
          ),
        ),
      );
    }

    return Semantics(
      label: 'User account information',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Email (read-only)
          Semantics(
            label: 'Email address',
            child: _InfoRow(
              label: 'Email',
              value: user.email ?? 'Not available',
            ),
          ),
          const SizedBox(height: 16),
          
          // Profile name
          if (_profileName != null) ...[
            Semantics(
              label: 'Profile name',
              child: _InfoRow(
                label: 'Name',
                value: _profileName!,
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          // Last sign-in
          Semantics(
            label: 'Last sign-in timestamp',
            child: _InfoRow(
              label: 'Last sign-in',
              value: _formatDate(user.lastSignInAt),
            ),
          ),
          
          // Account creation date
          const SizedBox(height: 16),
          Semantics(
            label: 'Account creation date',
            child: _InfoRow(
              label: 'Account created',
              value: _formatDate(user.createdAt),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

