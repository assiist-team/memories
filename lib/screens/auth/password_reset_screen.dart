import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:memories/providers/supabase_provider.dart';
import 'package:memories/services/auth_error_handler.dart';

/// Screen for password reset flow
/// 
/// Provides:
/// - Email input to trigger password reset
/// - Confirmation state after email is sent
/// - Error handling
class PasswordResetScreen extends StatefulWidget {
  const PasswordResetScreen({super.key});

  @override
  State<PasswordResetScreen> createState() => _PasswordResetScreenState();
}

class _PasswordResetScreenState extends State<PasswordResetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  
  bool _isLoading = false;
  bool _isEmailSent = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handlePasswordReset() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final container = ProviderScope.containerOf(context);
      final supabase = container.read(supabaseClientProvider);

      await supabase.auth.resetPasswordForEmail(
        _emailController.text.trim(),
      );

      setState(() {
        _isLoading = false;
        _isEmailSent = true;
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

  void _handleBackToLogin() {
    Navigator.of(context).pop();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // Show confirmation state if email was sent
    if (_isEmailSent) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Reset Password'),
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
                  label: 'Email sent icon',
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
                  'We sent a password reset link to',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                // Email address
                Semantics(
                  label: 'Email address where reset link was sent',
                  child: Text(
                    _emailController.text.trim(),
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 24),
                // Instructions
                Text(
                  'Please click the link in the email to reset your password. '
                  'If you don\'t see the email, check your spam folder.',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const Spacer(),
                // Back to login button
                Semantics(
                  label: 'Back to login button',
                  button: true,
                  child: ElevatedButton(
                    onPressed: _handleBackToLogin,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      minimumSize: const Size(0, 48),
                    ),
                    child: const Text('Back to Sign In'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Show password reset form
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reset Password'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                // Description
                Text(
                  'Enter your email address and we\'ll send you a link to reset your password.',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                // Email field
                Semantics(
                  label: 'Email input field',
                  textField: true,
                  child: TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      hintText: 'Enter your email',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    validator: _validateEmail,
                    autofocus: true,
                    autofillHints: const [AutofillHints.email],
                    onFieldSubmitted: (_) => _handlePasswordReset(),
                  ),
                ),
                const SizedBox(height: 24),
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
                if (_errorMessage != null) const SizedBox(height: 16),
                // Send reset link button
                Semantics(
                  label: 'Send reset link button',
                  button: true,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handlePasswordReset,
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
                        : const Text('Send reset link'),
                  ),
                ),
                const SizedBox(height: 16),
                // Back to login link
                Semantics(
                  label: 'Back to login link',
                  button: true,
                  child: TextButton(
                    onPressed: _handleBackToLogin,
                    child: const Text('Back to Sign In'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

