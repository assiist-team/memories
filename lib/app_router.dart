import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:memories/providers/auth_state_provider.dart';
import 'package:memories/screens/auth/login_screen.dart';
import 'package:memories/screens/auth/verification_wait_screen.dart';
import 'package:memories/screens/onboarding/onboarding_flow_screen.dart';
import 'package:memories/screens/main_navigation_shell.dart';
import 'package:memories/widgets/sync_service_initializer.dart';

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
      error: (error, stackTrace) {
        // Log the error for debugging
        debugPrint('AppRouter: Error in authStateProvider: $error');
        debugPrint('AppRouter: Stack trace: $stackTrace');
        
        // Show login screen with error message
        return const LoginScreen();
      },
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
        // Show main app - navigation shell with capture screen as default
        // Wrap in SyncServiceInitializer to start auto-sync
        return SyncServiceInitializer(
          child: const MainNavigationShell(),
        );
    }
  }
}
