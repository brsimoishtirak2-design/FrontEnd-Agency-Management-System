import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/providers.dart';
import '../../../shared/models/agency_user.dart';
import 'admin_users_repository.dart';

final adminUsersRepositoryProvider = Provider<AdminUsersRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  return AdminUsersRepository(api);
});

/// Auto-fetched list of active employees. For assignee picker.
final adminActiveEmployeesProvider =
    FutureProvider<List<AgencyUser>>((ref) async {
  final repo = ref.watch(adminUsersRepositoryProvider);
  return repo.listActiveEmployees();
});

/// Auto-fetched list of ALL users (admins + employees, active +
/// inactive). For the admin Employees tab.
final adminAllUsersProvider =
    FutureProvider<List<AgencyUser>>((ref) async {
  final repo = ref.watch(adminUsersRepositoryProvider);
  return repo.listUsers();
});

/// Auto-fetched single-user detail, family-keyed by id. Used by
/// detail / edit screens.
final adminUserDetailProvider =
    FutureProvider.family<AgencyUser, int>((ref, id) async {
  final repo = ref.watch(adminUsersRepositoryProvider);
  return repo.getUser(id);
});
