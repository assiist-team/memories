import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:memories/providers/supabase_provider.dart';
import 'package:memories/services/auth_error_handler.dart';

/// Screen shown while waiting for email verification
/// 
/// Provides:
/// - Information about verification email
/// - Resend email button
/// - Polling/resume logic to detect when verification is complete
/// - Deep link handling for verification callback
class VerificationWaitScreen extends StatefulWidget {
  final String email;

  const VerificationWaitScreen({
    super.key,
    required this.email,
  });

  @override
  State<VerificationWaitScreen> createState() => _VerificationWaitScreenState();
}

class _VerificationWaitScreenState extends State<VerificationWaitScreen> {
  bool _isResending = false;
  bool _isResent = false;
  String? _errorMessage;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  /// Start polling to check if email has been verified
  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      try {
        final container = ProviderScope.containerOf(context);
        final supabase = container.read(supabaseClientProvider);
        final user = supabase.auth.currentUser;

        if (user != null && user.emailConfirmedAt != null) {
          // Email verified, stop polling
          timer.cancel();
          // Auth state provider will handle navigation
        }
      } catch (e) {
        // Ignore polling errors, continue polling
      }
    });
  }

  Future<void> _handleResendEmail() async {
    setState(() {
      _isResending = true;
      _errorMessage = null;
      _isResent = false;
    });

    try {
      final container = ProviderScope.containerOf(context);
      final supabase = container.read(supabaseClientProvider);

      await supabase.auth.resend(
        type: OtpType.email,
        email: widget.email,
      );

      setState(() {
        _isResending = false;
        _isResent = true;
      });

      // Clear the "resent" message after 5 seconds
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) {
          setState(() {
            _isResent = false;
          });
        }
      });
    } catch (e) {
      final container = ProviderScope.containerOf(context);
      final errorHandler = container.read(authErrorHandlerProvider);
      setState(() {
        _errorMessage = errorHandler.handleAuthError(e);
        _isResending = false;
      });
    }
  }

  void _handleSignOut() async {
    try {
      final container = ProviderScope.containerOf(context);
      final supabase = container.read(supabaseClientProvider);
      await supabase.auth.signOut();
      // Navigation will be handled by auth state provider
    } catch (e) {
      // Handle error silently or show message
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Your Email'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 48),
              // Icon
              Semantics(
                label: 'Email verification icon',
                child: Icon(
                  Icons.mark_email_read_outlined,
                  size: 80,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 24),
              // Title
              Text(
                'Check your email',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              // Description
              Text(
                'We sent a verification link to',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              // Email address
              Semantics(
                label: 'Email address to verify',
                child: Text(
                  widget.email,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              // Instructions
              Text(
                'Please click the link in the email to verify your account. '
                'You can close this screen and return after verification.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              // Success message
              if (_isResent)
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
                      'Verification email sent!',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              if (_isResent) const SizedBox(height: 16),
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
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              if (_errorMessage != null) const SizedBox(height: 16),
              // Resend email button
              Semantics(
                label: 'Resend verification email button',
                button: true,
                child: OutlinedButton(
                  onPressed: _isResending ? null : _handleResendEmail,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    minimumSize: const Size(0, 48),
                  ),
                  child: _isResending
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Resend verification email'),
                ),
              ),
              const SizedBox(height: 16),
              // Sign out link
              Semantics(
                label: 'Sign out link',
                button: true,
                child: TextButton(
                  onPressed: _handleSignOut,
                  child: const Text('Sign Out'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

