import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/conflict_rules.dart';
import '../services/conflict_service.dart';

final bookingConflictServiceProvider = Provider<BookingConflictService>((ref) => BookingConflictService());

/// What one read of a club's conflicts is about. Equal queries share an answer.
class ConflictsQuery {
  const ConflictsQuery(this.venueId, {this.includeSettled = false});

  final String venueId;
  final bool includeSettled;

  @override
  bool operator ==(Object other) => other is ConflictsQuery && other.venueId == venueId && other.includeSettled == includeSettled;

  @override
  int get hashCode => Object.hash(venueId, includeSettled);
}

/// The club's double-booked tables. Not kept: a list from a minute ago is not what the manager must act on now.
final bookingConflictsProvider = FutureProvider.autoDispose.family<List<BookingConflict>, ConflictsQuery>(
  (ref, q) => ref.watch(bookingConflictServiceProvider).list(q.venueId, includeSettled: q.includeSettled),
);
