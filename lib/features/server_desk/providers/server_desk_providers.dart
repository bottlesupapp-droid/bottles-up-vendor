import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../floor/providers/floor_providers.dart' show FloorQuery;
import '../logic/server_desk_rules.dart';
import '../services/server_desk_service.dart';

final serverDeskServiceProvider = Provider<ServerDeskService>((ref) => ServerDeskService());

/// The signed-in server's tables for one business night. Not kept once the screen is gone: a stale list at a table is worse than a
/// slow one.
final myTablesProvider =
    FutureProvider.autoDispose.family<List<AssignedTable>, String>((ref, night) => ref.watch(serverDeskServiceProvider).myTables(night));

/// What one read of a club's requests is about. Equal queries share an answer.
class RequestsQuery {
  const RequestsQuery(this.venueId, {this.includeClosed = false});

  final String venueId;
  final bool includeClosed;

  @override
  bool operator ==(Object other) => other is RequestsQuery && other.venueId == venueId && other.includeClosed == includeClosed;

  @override
  int get hashCode => Object.hash(venueId, includeClosed);
}

final serviceRequestsProvider = FutureProvider.autoDispose.family<List<ServiceRequestRow>, RequestsQuery>(
  (ref, q) => ref.watch(serverDeskServiceProvider).requests(q.venueId, includeClosed: q.includeClosed),
);

/// Who has which booking at a club, for the nights the manager is looking at (the same query as the bookings list beside it).
final bookingServersProvider = FutureProvider.autoDispose.family<List<BookingServer>, FloorQuery>(
  (ref, q) => ref.watch(serverDeskServiceProvider).bookingServers(q.venueId, q.range),
);
