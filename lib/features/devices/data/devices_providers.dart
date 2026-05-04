import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/providers.dart';
import 'devices_repository.dart';

final devicesRepositoryProvider = Provider<DevicesRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  return DevicesRepository(api);
});
