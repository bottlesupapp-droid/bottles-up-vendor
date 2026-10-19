import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/owner_rules.dart';
import '../logic/setup_forms.dart';
import '../logic/venue_profile_rules.dart';
import '../services/media_service.dart';
import '../services/owner_service.dart';
import '../services/venue_setup_service.dart';

final ownerServiceProvider = Provider<OwnerService>((ref) => OwnerService());

/// The venues of one business. Not kept once the screens are gone: a stale list is worse than a slow one.
final ownerVenuesProvider = FutureProvider.autoDispose.family<List<OrgVenue>, String>((ref, orgId) {
  return ref.watch(ownerServiceProvider).venues(orgId);
});

/// How far one venue is set up.
final venueSetupProvider = FutureProvider.autoDispose.family<List<SetupStep>, String>((ref, venueId) {
  return ref.watch(ownerServiceProvider).setupStatus(venueId);
});

final venueSetupServiceProvider = Provider<VenueSetupService>((ref) => VenueSetupService());

/// The editors' lists. Not kept once the editor is closed: a stale menu or table list is worse than a slow one.
final arrivalTimesProvider = FutureProvider.autoDispose.family<List<ArrivalTime>, String>((ref, venueId) => ref.watch(venueSetupServiceProvider).arrivalTimes(venueId));
final tableTypesProvider = FutureProvider.autoDispose.family<List<TableTypeRow>, String>((ref, venueId) => ref.watch(venueSetupServiceProvider).tableTypes(venueId));
final bottlesProvider = FutureProvider.autoDispose.family<List<BottleRow>, String>((ref, venueId) => ref.watch(venueSetupServiceProvider).bottles(venueId));

final mediaServiceProvider = Provider<MediaService>((ref) => MediaService());
final floorsProvider = FutureProvider.autoDispose.family<List<FloorRow>, String>((ref, venueId) => ref.watch(venueSetupServiceProvider).floors(venueId));
final venueProfileProvider = FutureProvider.autoDispose.family<VenueProfile, String>((ref, venueId) => ref.watch(venueSetupServiceProvider).venueProfile(venueId));
