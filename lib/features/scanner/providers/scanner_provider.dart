import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/models/booking_model.dart';
import '../../../shared/services/booking_service.dart';

class ScannerNotifier extends StateNotifier<AsyncValue<void>> {
  final BookingService _bookingService = BookingService();

  ScannerNotifier() : super(const AsyncValue.data(null));

  Future<BookingModel> checkInTicket(String eventId, String ticketCode) async {
    state = const AsyncValue.loading();

    try {
      // Use the dedicated booking service
      final booking = await _bookingService.checkInBooking(ticketCode, eventId);
      state = const AsyncValue.data(null);
      return booking;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<BookingModel> validateTicket(String eventId, String ticketCode) async {
    try {
      return await _bookingService.validateTicketCode(ticketCode, eventId);
    } catch (e) {
      rethrow;
    }
  }
}

final scannerProvider = StateNotifierProvider<ScannerNotifier, AsyncValue<void>>((ref) {
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

final scanStatsProvider = FutureProvider.family<ScanStats, String>((ref, eventId) async {
  final supabase = Supabase.instance.client;

  // Fetch all bookings for the event
  final bookingsData = await supabase
      .from('events_bookings')
      .select('id, checked_in')
      .eq('event_id', eventId);

  final total = bookingsData.length;
  final checkedIn = bookingsData.where((b) => b['checked_in'] == true).length;
  final pending = total - checkedIn;

  return ScanStats(
    total: total,
    checkedIn: checkedIn,
    pending: pending,
  );
});
