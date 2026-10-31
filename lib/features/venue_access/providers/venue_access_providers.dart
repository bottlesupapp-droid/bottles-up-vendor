import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/access_rules.dart';
import '../services/venue_access_service.dart';

final venueAccessServiceProvider = Provider<VenueAccessService>((ref) => VenueAccessService());

/// One agreement's six things, read as [side] ('venue' for the club, 'organizer' for the organizer).
final agreementGrantsProvider = FutureProvider.autoDispose.family<AgreementGrants, ({String agreementId, String side})>((ref, q) => ref.watch(venueAccessServiceProvider).grants(q.agreementId, side: q.side));

final venueAccessProvider = FutureProvider.autoDispose.family<List<VenueAccessRow>, String>((ref, orgId) => ref.watch(venueAccessServiceProvider).venueAccess(orgId));

final eventSalesProvider = FutureProvider.autoDispose.family<EventSales, String>((ref, eventId) => ref.watch(venueAccessServiceProvider).eventSales(eventId));
