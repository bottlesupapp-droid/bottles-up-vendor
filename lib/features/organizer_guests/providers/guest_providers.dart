import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/guest_rules.dart';
import '../services/guest_service.dart';

final organizerGuestServiceProvider = Provider<OrganizerGuestService>((ref) => OrganizerGuestService());

final guestSummaryProvider = FutureProvider.autoDispose.family<GuestSummary, String>((ref, eventId) => ref.watch(organizerGuestServiceProvider).summary(eventId));

final guestListProvider = FutureProvider.autoDispose.family<List<Guest>, ({String eventId, String query})>(
  (ref, q) => ref.watch(organizerGuestServiceProvider).guests(q.eventId, query: q.query),
);
