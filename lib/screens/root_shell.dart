import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/pm_bottom_nav.dart';
import '../widgets/pm_logo.dart';
import 'calendar_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'simulation_screen.dart';
import 'status_screen.dart';

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  static const _screens = [
    HomeScreen(),
    SimulationScreen(),
    CalendarScreen(),
    StatusScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const PmLogo(size: 26),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_none_rounded, color: AppColors.textPrimary),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: PmBottomNav(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }
}
