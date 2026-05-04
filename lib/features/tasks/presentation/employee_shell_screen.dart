import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/data/auth_providers.dart';
import 'employee_profile_screen.dart';
import 'home_screen.dart';

/// Shell for the employee section — provides the bottom tab bar.
///
/// Two tabs:
///   0. Tasks   — assigned tasks list
///   1. Profile — worker info + logout
///
/// Logout lives on the Profile tab; the shell app bar has no actions.
class EmployeeShellScreen extends ConsumerStatefulWidget {
  const EmployeeShellScreen({super.key});

  @override
  ConsumerState<EmployeeShellScreen> createState() =>
      _EmployeeShellScreenState();
}

class _EmployeeShellScreenState extends ConsumerState<EmployeeShellScreen> {
  int _currentIndex = 0;

  static const _tabs = <Widget>[
    HomeScreen(),
    EmployeeProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final firstName = (authState is AuthAuthenticated)
        ? authState.user.name.split(' ').first
        : '';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _currentIndex == 0
              ? (firstName.isEmpty ? 'My Tasks' : 'Hi, $firstName')
              : 'Profile',
        ),
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _tabs,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        indicatorColor: AppTheme.brandPrimary.withValues(alpha: 0.18),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.task_alt_outlined, color: AppTheme.slate500),
            selectedIcon:
                Icon(Icons.task_alt, color: AppTheme.brandPrimaryDark),
            label: 'Tasks',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline, color: AppTheme.slate500),
            selectedIcon:
                Icon(Icons.person, color: AppTheme.brandPrimaryDark),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
