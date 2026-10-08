import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/door_rules.dart';
import '../services/door_service.dart';

final doorServiceProvider = Provider<DoorService>((ref) => DoorService());

/// The events one door workspace can work now. Re-read after every admission so the count of guests in stays true,
/// and not kept once the screen is gone (a stale list at a door is worse than a slow one).
final doorEventsProvider = FutureProvider.autoDispose.family<List<DoorEvent>, String>((ref, membershipId) {
  return ref.watch(doorServiceProvider).events(membershipId);
});

/// Which event the person chose, shared by the Scan and Guests tabs of one workspace so switching tabs keeps it.
/// Null means "not chosen yet": the screens fall back to [defaultEvent].
final selectedDoorEventProvider = StateProvider.family<String?, String>((ref, membershipId) => null);

/// The event actually in force: the chosen one if it is still on the list, otherwise the default.
DoorEvent? resolveEvent(List<DoorEvent> events, String? chosen, {DateTime? now}) {
  if (chosen != null) {
    for (final e in events) {
      if (e.eventId == chosen) return e;
    }
  }
  return defaultEvent(events, now: now);
}
