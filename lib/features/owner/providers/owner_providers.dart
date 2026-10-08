import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/owner_rules.dart';
import '../services/owner_service.dart';

final ownerServiceProvider = Provider<OwnerService>((ref) => OwnerService());

/// The venues of one business. Not kept once the screens are gone: a stale list is worse than a slow one.
final ownerVenuesProvider = FutureProvider.autoDispose.family<List<OrgVenue>, String>((ref, orgId) {
  return ref.watch(ownerServiceProvider).venues(orgId);
});

/// How far one venue is set up.
final venueSetupProvider = FutureProvider.autoDispose.family<List<SetupStep>, String>((ref, venueId) {
  return ref.watch(ownerServiceProvider).setupStatus(venueId);
});
