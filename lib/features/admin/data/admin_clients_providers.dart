import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/providers.dart';
import '../../../shared/models/agency_client.dart';
import 'admin_clients_repository.dart';

final adminClientsRepositoryProvider = Provider<AdminClientsRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  return AdminClientsRepository(api);
});

/// Auto-fetched list of active clients (no branches). For dropdown.
final adminClientsListProvider = FutureProvider<List<AgencyClient>>((ref) async {
  final repo = ref.watch(adminClientsRepositoryProvider);
  return repo.listClients();
});

/// Auto-fetched single client with branches. Family keyed by client id.
/// Used to populate the branch dropdown after user picks a client.
final adminClientWithBranchesProvider =
    FutureProvider.family<AgencyClient, int>((ref, id) async {
  final repo = ref.watch(adminClientsRepositoryProvider);
  return repo.getClientWithBranches(id);
});

/// Auto-fetched branches for a specific client. Family keyed by client id.
/// Used by the client detail screen's branches section.
final adminBranchesForClientProvider =
    FutureProvider.family<List<AgencyClientBranch>, int>((ref, clientId) async {
  final repo = ref.watch(adminClientsRepositoryProvider);
  return repo.listBranches(clientId: clientId);
});
