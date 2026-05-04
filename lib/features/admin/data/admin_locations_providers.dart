import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/providers.dart';
import '../../../shared/models/agency_location.dart';
import 'admin_locations_repository.dart';

final adminLocationsRepositoryProvider =
    Provider<AdminLocationsRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  return AdminLocationsRepository(api);
});

/// Auto-fetched list of locations. For branch-form location dropdown
/// and the admin Settings → Locations list.
final adminLocationsListProvider =
    FutureProvider<List<AgencyLocation>>((ref) async {
  final repo = ref.watch(adminLocationsRepositoryProvider);
  return repo.listLocations();
});

/// Auto-fetched single-location detail, family-keyed by id. Used by
/// the edit form to refresh after submit.
final adminLocationDetailProvider =
    FutureProvider.family<AgencyLocation, int>((ref, id) async {
  final repo = ref.watch(adminLocationsRepositoryProvider);
  return repo.getLocation(id);
});
