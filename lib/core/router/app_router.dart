import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/presentation/admin_client_detail_screen.dart';
import '../../features/admin/presentation/admin_shell_screen.dart';
import '../../features/admin/presentation/admin_departments_screen.dart';
import '../../features/admin/presentation/admin_employee_detail_screen.dart';
import '../../features/admin/presentation/admin_job_titles_screen.dart';
import '../../features/admin/presentation/employee_form_screen.dart';
import '../../features/admin/presentation/admin_locations_screen.dart';
import '../../features/admin/presentation/branch_form_screen.dart';
import '../../features/admin/presentation/client_form_screen.dart';
import '../../features/admin/presentation/create_task_screen.dart';
import '../../features/admin/presentation/department_form_screen.dart';
import '../../features/admin/presentation/job_title_form_screen.dart';
import '../../features/admin/presentation/location_form_screen.dart';
import '../../features/auth/data/auth_providers.dart';
import '../../features/auth/presentation/change_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/profile/presentation/edit_profile_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/profile/presentation/reset_password_screen.dart';
import '../../features/tasks/presentation/employee_shell_screen.dart';
import '../../features/tasks/presentation/task_assignees_screen.dart';
import '../../features/tasks/presentation/task_attach_picker_screen.dart';
import '../../features/tasks/presentation/task_comments_screen.dart';
import '../../features/tasks/presentation/task_detail_screen.dart';
import '../../shared/models/agency_client.dart';
import '../../shared/models/agency_department.dart';
import '../../shared/models/agency_job_title.dart';
import '../../shared/models/agency_location.dart';
import '../../shared/models/agency_user.dart';
import '../../shared/models/user.dart';

/// Route name constants — use these everywhere instead of magic strings.
class AppRoute {
  AppRoute._();
  static const splash = '/splash';
  static const login = '/login';
  static const changePassword = '/change-password';
  static const home = '/home';
  static const admin = '/admin';
  static const adminCreateTask = '/admin/tasks/new';
  static const adminClients = '/admin/clients';
  static const adminCreateClient = '/admin/clients/new';
  static const adminClientDetail = '/admin/clients';
  static const taskDetail = '/tasks';

  /// Builds the path for a specific task: /tasks/{id}
  static String taskDetailPath(int id) => '$taskDetail/$id';

  /// Builds the path for a task's assignees screen: /tasks/{id}/assignees
  static String taskAssigneesPath(int id) => '$taskDetail/$id/assignees';

  /// Builds the path for a task's chat-style comments screen:
  /// /tasks/{id}/comments
  static String taskCommentsPath(int id) => '$taskDetail/$id/comments';

  /// Builds the path for a task's attach-file picker screen:
  /// /tasks/{id}/attach
  static String taskAttachPath(int id) => '$taskDetail/$id/attach';

  /// Builds the path for a specific client: /admin/clients/{id}
  static String adminClientDetailPath(int id) => '$adminClientDetail/$id';

  /// Builds the edit path for a specific client: /admin/clients/{id}/edit
  static String adminEditClientPath(int id) => '$adminClients/$id/edit';

  /// Base for client-scoped branch routes; mirrors `adminClients`.
  static const adminAddBranchToClient = '/admin/clients';

  /// Builds the path for adding a branch under a client:
  /// /admin/clients/{clientId}/branches/new
  static String adminAddBranchToClientPath(int clientId) =>
      '$adminAddBranchToClient/$clientId/branches/new';

  /// Builds the edit path for a specific branch:
  /// /admin/clients/{clientId}/branches/{branchId}/edit
  static String adminEditBranchPath(int clientId, int branchId) =>
      '$adminAddBranchToClient/$clientId/branches/$branchId/edit';

  // Employees CRUD.
  static const adminEmployees = '/admin/employees';
  static const adminCreateEmployee = '/admin/employees/new';

  /// Builds the detail path for a specific employee:
  /// /admin/employees/{id}
  static String adminEmployeeDetailPath(int id) =>
      '$adminEmployees/$id';

  /// Builds the edit path for a specific employee:
  /// /admin/employees/{id}/edit
  static String adminEditEmployeePath(int id) =>
      '$adminEmployees/$id/edit';

  // Settings sub-screens (org structure).
  static const adminLocations = '/admin/settings/locations';
  static const adminCreateLocation = '/admin/settings/locations/new';
  static const adminLocationEdit = '/admin/settings/locations';
  static const adminJobTitles = '/admin/settings/job-titles';
  static const adminCreateJobTitle = '/admin/settings/job-titles/new';
  static const adminJobTitleEdit = '/admin/settings/job-titles';
  static const adminDepartments = '/admin/settings/departments';
  static const adminCreateDepartment = '/admin/settings/departments/new';
  static const adminDepartmentEdit = '/admin/settings/departments';

  /// Builds the edit path for a specific location:
  /// /admin/settings/locations/{id}/edit
  static String adminEditLocationPath(int id) =>
      '$adminLocationEdit/$id/edit';

  /// Builds the edit path for a specific job title:
  /// /admin/settings/job-titles/{id}/edit
  static String adminEditJobTitlePath(int id) =>
      '$adminJobTitleEdit/$id/edit';

  /// Builds the edit path for a specific department:
  /// /admin/settings/departments/{id}/edit
  static String adminEditDepartmentPath(int id) =>
      '$adminDepartmentEdit/$id/edit';

  // Self-service profile (any authenticated user).
  static const profile = '/profile';
  static const editProfile = '/profile/edit';
  // Voluntary self-service password reset. Distinct from
  // [changePassword] above which is the forced first-login flow.
  // The reset flow does not require the current password.
  static const selfResetPassword = '/profile/reset-password';

  // Notifications inbox (any authenticated user).
  static const notifications = '/notifications';
}

/// Provides the global GoRouter, configured to react to auth state changes.
final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterRefreshNotifier(ref);

  return GoRouter(
    initialLocation: AppRoute.splash,
    refreshListenable: notifier,
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      final location = state.matchedLocation;

      if (authState is AuthInitial || authState is AuthLoading) {
        return location == AppRoute.splash ? null : AppRoute.splash;
      }

      if (authState is AuthUnauthenticated) {
        return location == AppRoute.login ? null : AppRoute.login;
      }

      if (authState is AuthPasswordChangeRequired) {
        return location == AppRoute.changePassword
            ? null
            : AppRoute.changePassword;
      }

      if (authState is AuthAuthenticated) {
        final user = authState.user;
        // Block auth-only routes while authenticated.
        if (location == AppRoute.login ||
            location == AppRoute.splash ||
            location == AppRoute.changePassword) {
          return _homePathFor(user);
        }
        // Role-based gating: admin's home is /admin, employee's home is /home.
        // Redirect if a user lands on the wrong root.
        if (user.isAdmin && location == AppRoute.home) {
          return AppRoute.admin;
        }
        if (user.isEmployee && location == AppRoute.admin) {
          return AppRoute.home;
        }
        return null;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoute.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoute.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoute.changePassword,
        builder: (context, state) => const ChangePasswordScreen(),
      ),
      GoRoute(
        path: AppRoute.home,
        builder: (context, state) => const EmployeeShellScreen(),
      ),
      GoRoute(
        path: AppRoute.admin,
        builder: (context, state) => const AdminShellScreen(),
      ),
      GoRoute(
        path: AppRoute.adminCreateTask,
        builder: (context, state) => const CreateTaskScreen(),
      ),
      GoRoute(
        path: AppRoute.adminCreateClient,
        builder: (context, state) => const ClientFormScreen(),
      ),
      GoRoute(
        path: '${AppRoute.adminClients}/:id/edit',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is AgencyClient) {
            return ClientFormScreen(initialClient: extra);
          }
          return const Scaffold(
            body: Center(
              child: Text('Edit requires opening from client detail.'),
            ),
          );
        },
      ),
      GoRoute(
        path: '${AppRoute.adminClients}/:clientId/branches/new',
        builder: (context, state) {
          final clientIdStr = state.pathParameters['clientId'] ?? '';
          final clientId = int.tryParse(clientIdStr) ?? 0;
          return BranchFormScreen(clientId: clientId);
        },
      ),
      GoRoute(
        path:
            '${AppRoute.adminClients}/:clientId/branches/:branchId/edit',
        builder: (context, state) {
          final clientIdStr = state.pathParameters['clientId'] ?? '';
          final clientId = int.tryParse(clientIdStr) ?? 0;
          final extra = state.extra;
          if (extra is AgencyClientBranch) {
            return BranchFormScreen(
              clientId: clientId,
              initialBranch: extra,
            );
          }
          return const Scaffold(
            body: Center(
              child: Text('Edit requires opening from client detail.'),
            ),
          );
        },
      ),
      GoRoute(
        path: '${AppRoute.adminClientDetail}/:id',
        builder: (context, state) {
          final idStr = state.pathParameters['id'] ?? '';
          final id = int.tryParse(idStr) ?? 0;
          return AdminClientDetailScreen(clientId: id);
        },
      ),
      GoRoute(
        path: AppRoute.adminCreateEmployee,
        builder: (context, state) => const EmployeeFormScreen(),
      ),
      GoRoute(
        path: '${AppRoute.adminEmployees}/:id/edit',
        builder: (context, state) {
          final user = state.extra as AgencyUser?;
          if (user != null) {
            return EmployeeFormScreen(initialUser: user);
          }
          return const Scaffold(
            body: Center(
              child: Text('Edit requires opening from employee detail.'),
            ),
          );
        },
      ),
      GoRoute(
        path: '${AppRoute.adminEmployees}/:id',
        builder: (context, state) {
          final idStr = state.pathParameters['id'] ?? '';
          final id = int.tryParse(idStr) ?? 0;
          return AdminEmployeeDetailScreen(userId: id);
        },
      ),
      GoRoute(
        path: AppRoute.adminLocations,
        builder: (context, state) => const AdminLocationsScreen(),
      ),
      GoRoute(
        path: AppRoute.adminCreateLocation,
        builder: (context, state) => const LocationFormScreen(),
      ),
      GoRoute(
        path: '${AppRoute.adminLocationEdit}/:id/edit',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is AgencyLocation) {
            return LocationFormScreen(initialLocation: extra);
          }
          return const Scaffold(
            body: Center(
              child: Text('Edit requires opening from list.'),
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoute.adminJobTitles,
        builder: (context, state) => const AdminJobTitlesScreen(),
      ),
      GoRoute(
        path: AppRoute.adminCreateJobTitle,
        builder: (context, state) => const JobTitleFormScreen(),
      ),
      GoRoute(
        path: '${AppRoute.adminJobTitleEdit}/:id/edit',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is AgencyJobTitle) {
            return JobTitleFormScreen(initialJobTitle: extra);
          }
          return const Scaffold(
            body: Center(
              child: Text('Edit requires opening from list.'),
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoute.adminDepartments,
        builder: (context, state) => const AdminDepartmentsScreen(),
      ),
      GoRoute(
        path: AppRoute.adminCreateDepartment,
        builder: (context, state) => const DepartmentFormScreen(),
      ),
      GoRoute(
        path: '${AppRoute.adminDepartmentEdit}/:id/edit',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is AgencyDepartment) {
            return DepartmentFormScreen(initialDepartment: extra);
          }
          return const Scaffold(
            body: Center(
              child: Text('Edit requires opening from list.'),
            ),
          );
        },
      ),
      GoRoute(
        path: '${AppRoute.taskDetail}/:id/assignees',
        builder: (context, state) {
          final idStr = state.pathParameters['id'] ?? '';
          final id = int.tryParse(idStr) ?? 0;
          return TaskAssigneesScreen(taskId: id);
        },
      ),
      GoRoute(
        path: '${AppRoute.taskDetail}/:id/comments',
        builder: (context, state) {
          final idStr = state.pathParameters['id'] ?? '';
          final id = int.tryParse(idStr) ?? 0;
          return TaskCommentsScreen(taskId: id);
        },
      ),
      GoRoute(
        path: '${AppRoute.taskDetail}/:id/attach',
        builder: (context, state) {
          final idStr = state.pathParameters['id'] ?? '';
          final id = int.tryParse(idStr) ?? 0;
          return TaskAttachPickerScreen(taskId: id);
        },
      ),
      GoRoute(
        path: '${AppRoute.taskDetail}/:id',
        builder: (context, state) {
          final idStr = state.pathParameters['id'] ?? '';
          final id = int.tryParse(idStr) ?? 0;
          return TaskDetailScreen(taskId: id);
        },
      ),
      GoRoute(
        path: AppRoute.profile,
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: AppRoute.editProfile,
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: AppRoute.selfResetPassword,
        builder: (context, state) => const ResetPasswordScreen(),
      ),
      GoRoute(
        path: AppRoute.notifications,
        builder: (context, state) => const NotificationsScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.uri}'),
      ),
    ),
  );
});

/// Returns the post-login landing route for a given user, based on role.
String _homePathFor(User user) {
  return user.isAdmin ? AppRoute.admin : AppRoute.home;
}

class _RouterRefreshNotifier extends ChangeNotifier {
  late final ProviderSubscription<AuthState> _sub;

  _RouterRefreshNotifier(Ref ref) {
    _sub = ref.listen<AuthState>(
      authStateProvider,
      (_, _) => notifyListeners(),
      fireImmediately: false,
    );
  }

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}
