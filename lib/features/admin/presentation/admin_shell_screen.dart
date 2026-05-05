import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/notifications_bell_button.dart';
import '../../../shared/widgets/profile_avatar_button.dart';
import '../../../shared/widgets/search_app_bar.dart';
import '../../auth/data/auth_providers.dart';
import '../data/admin_tasks_providers.dart';
import 'admin_clients_screen.dart';
import 'admin_employees_screen.dart';
import 'admin_settings_screen.dart';
import 'admin_tasks_screen.dart';

/// Shell for the admin section — provides the bottom tab bar.
///
/// Four tabs:
///   0. Tasks    — see all tasks across all employees (search-enabled)
///   1. Clients  — manage clients + branches
///   2. Employees — manage user accounts
///   3. Settings — org structure
///
/// The AppBar adapts per-tab: Tasks uses [SearchAppBar] so the admin
/// can search across all tasks; the other tabs use a plain AppBar.
class AdminShellScreen extends ConsumerStatefulWidget {
  const AdminShellScreen({super.key});

  @override
  ConsumerState<AdminShellScreen> createState() => _AdminShellScreenState();
}

class _AdminShellScreenState extends ConsumerState<AdminShellScreen> {
  int _currentIndex = 0;
  Timer? _searchDebounce;

  static const _tabs = <Widget>[
    AdminTasksScreen(),
    AdminClientsScreen(),
    AdminEmployeesScreen(),
    AdminSettingsScreen(),
  ];

  static const _titles = <String>[
    'Tasks',
    'Clients',
    'Employees',
    'Settings',
  ];

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onTaskSearchChanged(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      ref.read(adminTasksFiltersProvider.notifier).setSearch(query);
    });
  }

  PreferredSizeWidget _buildAppBar(String adminName) {
    if (_currentIndex == 0) {
      // Watch — the SearchAppBar runs in controlled mode, so the shell
      // must rebuild whenever filters.search changes (including from
      // external sources like the empty-state Clear filters button).
      final filters = ref.watch(adminTasksFiltersProvider);
      return SearchAppBar(
        title: 'Hi, $adminName',
        showBackButton: false,
        hintText: 'Search tasks by title or description',
        query: filters.search,
        onChanged: _onTaskSearchChanged,
        actions: const [
          NotificationsBellButton(),
          ProfileAvatarButton(),
        ],
      );
    }

    return AppBar(
      title: Text(_titles[_currentIndex]),
      actions: const [ProfileAvatarButton()],
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final adminName = (authState is AuthAuthenticated)
        ? authState.user.name.split(' ').first
        : 'Admin';

    return Scaffold(
      appBar: _buildAppBar(adminName),
      body: IndexedStack(
        index: _currentIndex,
        children: _tabs,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        indicatorColor: AppTheme.brandPrimary.withValues(alpha: 0.18),
        // Make selected vs unselected unambiguous: selected icons get
        // the brand color; unselected get muted slate so the user can
        // tell at a glance which tab is active.
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.task_alt_outlined, color: AppTheme.slate500),
            selectedIcon:
                Icon(Icons.task_alt, color: AppTheme.brandPrimaryDark),
            label: 'Tasks',
          ),
          NavigationDestination(
            icon: Icon(Icons.business_outlined, color: AppTheme.slate500),
            selectedIcon:
                Icon(Icons.business, color: AppTheme.brandPrimaryDark),
            label: 'Clients',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline, color: AppTheme.slate500),
            selectedIcon:
                Icon(Icons.people, color: AppTheme.brandPrimaryDark),
            label: 'Employees',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined, color: AppTheme.slate500),
            selectedIcon:
                Icon(Icons.settings, color: AppTheme.brandPrimaryDark),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
