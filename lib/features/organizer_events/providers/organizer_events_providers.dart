import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/organizer_events_rules.dart';
import '../services/organizer_events_service.dart';

final organizerEventsServiceProvider = Provider<OrganizerEventsService>((ref) => OrganizerEventsService());

/// The events of one business. Not kept once the screen is gone: a stale list is worse than a slow one.
final organizerEventsProvider =
    FutureProvider.autoDispose.family<List<OrgEvent>, String>((ref, orgId) => ref.watch(organizerEventsServiceProvider).events(orgId));
