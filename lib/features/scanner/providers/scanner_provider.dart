import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/models/booking_model.dart';

class ScannerNotifier extends StateNotifier<AsyncValue<void>> {
  ScannerNotifier() : super(const AsyncValue.data(null));

  Future<BookingModel> checkInTicket(String eventId, String ticketCode) async {
    state = const AsyncValue.loading();

    try {
      final supabase = Supabase.instance.client;
      final currentUserId = supabase.auth.currentUser?.id;

      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }

      // Fetch booking by ticket code
      final bookingData = await supabase
          .from('events_bookings')
          .select('''
            *,
            events!inner(id, name, user_id)
          ''')
          .eq('ticket_code', ticketCode)
          .eq('event_id', eventId)
          .single();

      // Verify event belongs to current user
      if (bookingData['events']['user_id'] != currentUserId) {
        throw Exception('Unauthorized access to event');
      }

      // Check if already checked in
      if (bookingData['checked_in'] == true) {
        throw Exception('Ticket already checked in');
      }

      // Update booking to mark as checked in
      final now = DateTime.now();
      await supabase
          .from('events_bookings')
          .update({
            'checked_in': true,
            'checked_in_at': now.toIso8601String(),
            'checked_in_by': currentUserId,
            'updated_at': now.toIso8601String(),
          })
          .eq('id', bookingData['id']);

      state = const AsyncValue.data(null);

      // Return updated booking model
      return BookingModel(
        id: bookingData['id'],
        eventId: bookingData['event_id'],
        eventName: bookingData['events']['name'],
        userId: bookingData['user_id'],
        customerName: bookingData['customer_name'],
        customerEmail: bookingData['customer_email'],
        customerPhone: bookingData['customer_phone'],
        bookingType: _parseBookingType(bookingData['booking_type']),
        status: _parseBookingStatus(bookingData['status']),
        quantity: bookingData['quantity'] ?? 1,
        totalAmount: (bookingData['total_amount'] ?? 0).toDouble(),
        paidAmount: (bookingData['paid_amount'] ?? 0).toDouble(),
        ticketCode: bookingData['ticket_code'],
        qrCode: bookingData['qr_code'],
        checkedIn: true,
        checkedInAt: now,
        checkedInBy: currentUserId,
        createdAt: DateTime.parse(bookingData['created_at']),
        updatedAt: now,
      );
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  BookingType _parseBookingType(String? type) {
    switch (type) {
      case 'ticket':
        return BookingType.ticket;
      case 'table':
        return BookingType.table;
      case 'bottle':
        return BookingType.bottle;
      case 'vip':
        return BookingType.vip;
      default:
        return BookingType.ticket;
    }
  }

  BookingStatus _parseBookingStatus(String? status) {
    switch (status) {
      case 'pending':
        return BookingStatus.pending;
      case 'confirmed':
        return BookingStatus.confirmed;
      case 'checkedIn':
        return BookingStatus.checkedIn;
      case 'cancelled':
        return BookingStatus.cancelled;
      case 'refunded':
        return BookingStatus.refunded;
      default:
        return BookingStatus.pending;
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
