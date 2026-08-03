import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';
import '../widgets/pm_bottom_nav.dart';
import '../widgets/pm_logo.dart';

/// The five-tab chrome (AppBar + bottom nav), now driven by go_router's
/// [StatefulShellRoute.indexedStack] instead of a manually-managed
/// `IndexedStack` index. [navigationShell] already keeps each branch's
/// widget tree alive when switching tabs — the same "state isn't lost when
/// you change tabs" behavior the old `IndexedStack` gave us, just owned by
/// the router now. The five tab screens themselves are unchanged.
class RootShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const RootShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const PmLogo(size: 26),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_none_rounded,
                color: AppColors.textPrimary),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: navigationShell,
      bottomNavigationBar: PmBottomNav(
        currentIndex: navigationShell.currentIndex,
        onTap: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
      ),
    );
  }
}
