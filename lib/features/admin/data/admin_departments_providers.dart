import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/providers.dart';
import '../../../shared/models/agency_department.dart';
import 'admin_departments_repository.dart';

final adminDepartmentsRepositoryProvider =
    Provider<AdminDepartmentsRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  return AdminDepartmentsRepository(api);
});

/// Auto-fetched list of departments (with eager-loaded location).
final adminDepartmentsListProvider =
    FutureProvider<List<AgencyDepartment>>((ref) async {
  final repo = ref.watch(adminDepartmentsRepositoryProvider);
  return repo.listDepartments();
});

/// Auto-fetched single-department detail, family-keyed by id.
final adminDepartmentDetailProvider =
    FutureProvider.family<AgencyDepartment, int>((ref, id) async {
  final repo = ref.watch(adminDepartmentsRepositoryProvider);
  return repo.getDepartment(id);
});
