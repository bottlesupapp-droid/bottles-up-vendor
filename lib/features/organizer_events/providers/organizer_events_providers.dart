import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/event_states.dart';
import '../logic/organizer_events_rules.dart';
import '../services/organizer_events_service.dart';

final organizerEventsServiceProvider = Provider<OrganizerEventsService>((ref) => OrganizerEventsService());

/// The events of one business. Not kept once the screen is gone: a stale list is worse than a slow one.
final organizerEventsProvider =
    FutureProvider.autoDispose.family<List<OrgEvent>, String>((ref, orgId) => ref.watch(organizerEventsServiceProvider).events(orgId));

/// Where each event stands and what blocks publishing it. Kept apart from the events themselves so the list still shows if this cannot be read.
final organizerEventStatesProvider =
    FutureProvider.autoDispose.family<Map<String, EventStateInfo>, String>((ref, orgId) async => statesByEvent(await ref.watch(organizerEventsServiceProvider).states(orgId)));
