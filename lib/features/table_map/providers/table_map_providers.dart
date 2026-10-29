import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/table_map_rules.dart';
import '../services/table_map_service.dart';

final tableMapServiceProvider = Provider<TableMapService>((ref) => TableMapService());

class MapQuery {
  const MapQuery(this.venueId, this.night);

  final String venueId;
  final String night;

  @override
  bool operator ==(Object other) => other is MapQuery && other.venueId == venueId && other.night == night;

  @override
  int get hashCode => Object.hash(venueId, night);
}

/// What is free, booked, held and unavailable on one night. Never kept: a stale count is how a table is sold twice.
final tableStatesProvider =
    FutureProvider.autoDispose.family<List<MapSlot>, MapQuery>((ref, q) => ref.watch(tableMapServiceProvider).states(q.venueId, q.night));

final tableBlocksProvider =
    FutureProvider.autoDispose.family<List<TableBlock>, MapQuery>((ref, q) => ref.watch(tableMapServiceProvider).blocks(q.venueId, q.night));

final moveOptionsProvider = FutureProvider.autoDispose.family<List<MoveOption>, String>((ref, bookingId) => ref.watch(tableMapServiceProvider).moveOptions(bookingId));

final bookingMovesProvider = FutureProvider.autoDispose.family<List<BookingMove>, String>((ref, bookingId) => ref.watch(tableMapServiceProvider).moves(bookingId));

final bookingTermsProvider = FutureProvider.autoDispose.family<BookingTerms, String>((ref, bookingId) => ref.watch(tableMapServiceProvider).bookingTerms(bookingId));

final tableLayoutProvider = FutureProvider.autoDispose.family<List<TableLayout>, String>((ref, venueId) => ref.watch(tableMapServiceProvider).layout(venueId));

final depositSettingsProvider = FutureProvider.autoDispose.family<DepositSettings, String>((ref, venueId) => ref.watch(tableMapServiceProvider).depositSettings(venueId));
