import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:memories/providers/auth_state_provider.dart';
import 'package:memories/screens/auth/login_screen.dart';
import 'package:memories/screens/auth/verification_wait_screen.dart';
import 'package:memories/screens/onboarding/onboarding_flow_screen.dart';

/// Main app router that handles navigation based on authentication state
///
/// Routes users to the appropriate screen based on their authentication,
/// verification, and onboarding status.
class AppRouter extends ConsumerWidget {
  const AppRouter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (state) => _buildRouteForState(state),
      loading: () => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      ),
      error: (_, __) => const LoginScreen(),
    );
  }

  Widget _buildRouteForState(AuthRoutingState authState) {
    switch (authState.routeState) {
      case AuthRouteState.unauthenticated:
        // Show login screen (users can navigate to signup from there)
        return const LoginScreen();

      case AuthRouteState.unverified:
        // Show verification wait screen
        final email = authState.user?.email ?? '';
        return VerificationWaitScreen(email: email);

      case AuthRouteState.onboarding:
        // Show onboarding flow
        if (authState.user == null) {
          // Fallback to login if user is null
          return const LoginScreen();
        }
        return OnboardingFlowScreen(user: authState.user!);

      case AuthRouteState.authenticated:
        // Show main app shell (placeholder for now)
        // TODO: Replace with actual main shell when implemented
        return Scaffold(
          appBar: AppBar(
            title: const Text('Memories'),
          ),
          body: const Center(
            child: Text('Welcome to Memories!\nMain app coming soon.'),
          ),
        );
    }
  }
}
