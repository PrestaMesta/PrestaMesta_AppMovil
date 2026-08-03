import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/pm_logo.dart';

/// Shown only while [AuthStatus.restoring] — the router's redirect logic
/// forces every other location back here during that window, so the shell
/// (or login) never flashes before the session is known one way or the
/// other.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PmLogo(size: 30),
            SizedBox(height: 24),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
