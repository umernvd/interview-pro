import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/app_router.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/service_locator.dart';

/// Provider for managing splash screen state and navigation
class SplashProvider extends ChangeNotifier {
  bool _isLoading = true;

  SplashProvider();

  bool get isLoading => _isLoading;

  /// Start the splash screen timer and navigate to appropriate screen after delay
  Future<void> startSplashTimer(BuildContext context) async {
    // Minimum splash time for branding
    final minSplashTime = Future.delayed(
      Duration(milliseconds: AppConstants.splashDuration),
    );

    // Attempt to restore magic auth code session
    final authService = sl<AuthService>();
    bool sessionRestored = false;

    try {
      sessionRestored = await authService.restoreSessionOnStartup().timeout(
        const Duration(seconds: 3),
        onTimeout: () => false,
      );
    } catch (e) {
      debugPrint('⚠️ Session restoration failed: $e');
      sessionRestored = false;
    }

    // Wait for minimum splash time and auth attempts
    await minSplashTime;

    if (context.mounted) {
      _navigateBasedOnAuthState(context, sessionRestored);
    }
  }

  /// Navigate based on authentication state
  void _navigateBasedOnAuthState(BuildContext context, bool sessionRestored) {
    if (context.mounted) {
      _isLoading = false;
      notifyListeners();

      if (sessionRestored) {
        // Session restored successfully - go to dashboard
        context.go(AppRouter.dashboard);
      } else {
        // No session - go to login screen
        context.go(AppRouter.login);
      }
    }
  }
}
