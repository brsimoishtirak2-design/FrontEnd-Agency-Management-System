import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/providers.dart';
import '../../../shared/models/agency_job_title.dart';
import 'admin_job_titles_repository.dart';

final adminJobTitlesRepositoryProvider =
    Provider<AdminJobTitlesRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  return AdminJobTitlesRepository(api);
});

/// Auto-fetched list of job titles. For the admin Settings → Job Titles
/// list and any future picker UI.
final adminJobTitlesListProvider =
    FutureProvider<List<AgencyJobTitle>>((ref) async {
  final repo = ref.watch(adminJobTitlesRepositoryProvider);
  return repo.listJobTitles();
});

/// Auto-fetched single-job-title detail, family-keyed by id.
final adminJobTitleDetailProvider =
    FutureProvider.family<AgencyJobTitle, int>((ref, id) async {
  final repo = ref.watch(adminJobTitlesRepositoryProvider);
  return repo.getJobTitle(id);
});
