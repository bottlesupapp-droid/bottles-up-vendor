import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/services/check_in_service.dart';

class ScannerNotifier extends StateNotifier<AsyncValue<void>> {
  final CheckInService _checkInService = CheckInService();

  ScannerNotifier() : super(const AsyncValue.data(null));

  /// Check in a ticket. [eventId] is optional — if provided, search is scoped to that event.
  Future<UnifiedTicket> checkInTicket(String ticketCode, {String? eventId}) async {
    state = const AsyncValue.loading();
    try {
      final ticket = await _checkInService.checkIn(ticketCode, eventId: eventId);
      state = const AsyncValue.data(null);
      return ticket;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<UnifiedTicket?> validateTicket(String ticketCode, {String? eventId}) async {
    try {
      return await _checkInService.findByCode(ticketCode, eventId: eventId);
    } catch (e) {
      rethrow;
    }
  }
}

final scannerProvider =
    StateNotifierProvider<ScannerNotifier, AsyncValue<void>>((ref) {
  return ScannerNotifier();
});

class ScanStats {
  final int total;
  final int checkedIn;
  final int pending;

  const ScanStats({
    required this.total,
    required this.checkedIn,
    required this.pending,
  });
}

/// Stats for a specific event's bookings (event scanner mode).
final scanStatsProvider =
    FutureProvider.family<ScanStats, String>((ref, eventId) async {
  final supabase = Supabase.instance.client;
  final data = await supabase
      .from('events_bookings')
      .select('id, checked_in')
      .eq('event_id', eventId);

  final total = data.length;
  final checkedIn = data.where((b) => b['checked_in'] == true).length;
  return ScanStats(total: total, checkedIn: checkedIn, pending: total - checkedIn);
});

/// Stats for all bookings owned by the current vendor (open scanner mode).
final vendorScanStatsProvider = FutureProvider<ScanStats>((ref) async {
  final supabase = Supabase.instance.client;
  final vendorId = supabase.auth.currentUser?.id;
  if (vendorId == null) return const ScanStats(total: 0, checkedIn: 0, pending: 0);

  final evData = await supabase
      .from('events_bookings')
      .select('id, checked_in, events!inner(user_id)')
      .eq('events.user_id', vendorId);

  final tbData = await supabase
      .from('table_bookings')
      .select('id, checked_in, club_tables!inner(clubs!inner(owner_id))')
      .eq('club_tables.clubs.owner_id', vendorId);

  final allCheckedIn = [
    ...evData.where((b) => b['checked_in'] == true),
    ...tbData.where((b) => b['checked_in'] == true),
  ];
  final total = evData.length + tbData.length;
  final checkedIn = allCheckedIn.length;

  return ScanStats(total: total, checkedIn: checkedIn, pending: total - checkedIn);
});
