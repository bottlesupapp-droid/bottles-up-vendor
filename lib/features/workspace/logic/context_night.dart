import 'package:intl/intl.dart';

import '../../floor/logic/bookings_rules.dart' show currentNight;
import '../models/workspace.dart';

/// The night shown in the bar at the top of every workspace (brief: "Keep the active venue, event, and night visible on every operational screen").
/// It is the business night it is now: before 06:00 it is still the previous night, the same night Tonight and the bookings use.
/// An event workspace (door staff or an organizer's team for one event) names the event instead, so it has no separate night line.
String? contextNightLine(Workspace workspace, DateTime now) {
  if (workspace.eventId != null) return null;
  return 'Night of ${DateFormat('EEE d MMM').format(DateTime.parse(currentNight(now)))}';
}
