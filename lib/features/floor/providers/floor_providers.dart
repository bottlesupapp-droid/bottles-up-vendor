import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/bookings_rules.dart';
import '../services/floor_service.dart';

final floorServiceProvider = Provider<FloorService>((ref) => FloorService());

/// What one read of bookings is about. Equal queries share an answer.
class FloorQuery {
  const FloorQuery(this.venueId, this.range);

  final String venueId;
  final NightRange range;

  @override
  bool operator ==(Object other) => other is FloorQuery && other.venueId == venueId && other.range == range;

  @override
  int get hashCode => Object.hash(venueId, range);
}

/// The bookings of a venue for some nights. Not kept once the screen is gone: a stale list on a floor is worse than a slow one.
final floorBookingsProvider = FutureProvider.autoDispose.family<List<BookingRow>, FloorQuery>((ref, query) {
  return ref.watch(floorServiceProvider).bookings(query.venueId, query.range);
});
