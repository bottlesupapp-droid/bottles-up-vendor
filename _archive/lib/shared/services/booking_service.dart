import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/booking_model.dart';

class BookingService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Validate ticket code and return booking if valid
  Future<BookingModel> validateTicketCode(String ticketCode, String eventId) async {
    try {
      final response = await _supabase
          .from('events_bookings')
          .select('''
            *,
            events!inner(id, name, user_id)
          ''')
          .eq('ticket_code', ticketCode)
          .eq('event_id', eventId)
          .maybeSingle();

      if (response == null) {
        throw Exception('Invalid ticket code');
      }

      // Verify event belongs to current user
      final currentUserId = _supabase.auth.currentUser?.id;
      if (response['events']['user_id'] != currentUserId) {
        throw Exception('Unauthorized: This ticket belongs to a different event');
      }

      return _bookingFromJson(response);
    } catch (e) {
      throw Exception('Failed to validate ticket: $e');
    }
  }

  /// Check in a booking using ticket code
  Future<BookingModel> checkInBooking(String ticketCode, String eventId) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }

      // First validate the ticket
      final booking = await validateTicketCode(ticketCode, eventId);

      // Check if already checked in
      if (booking.checkedIn) {
        throw Exception(
          'Already checked in at ${_formatDateTime(booking.checkedInAt!)}',
        );
      }

      // Check if booking is confirmed
      if (booking.status != BookingStatus.confirmed) {
        throw Exception('Booking status is ${booking.status.name}. Only confirmed bookings can be checked in.');
      }

      // Update booking to mark as checked in
      final now = DateTime.now();
      await _supabase
          .from('events_bookings')
          .update({
            'checked_in': true,
            'checked_in_at': now.toIso8601String(),
            'checked_in_by': currentUserId,
            'status': BookingStatus.checkedIn.name,
            'updated_at': now.toIso8601String(),
          })
          .eq('id', booking.id);

      // Return updated booking
      return booking.copyWith(
        checkedIn: true,
        checkedInAt: now,
        checkedInBy: currentUserId,
        status: BookingStatus.checkedIn,
        updatedAt: now,
      );
    } catch (e) {
      throw Exception('Check-in failed: $e');
    }
  }

  /// Get all bookings for an event
  Future<List<BookingModel>> getEventBookings(String eventId) async {
    try {
      final response = await _supabase
          .from('events_bookings')
          .select('''
            *,
            events(id, name)
          ''')
          .eq('event_id', eventId)
          .order('created_at', ascending: false);

      return (response as List).map((json) => _bookingFromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to fetch bookings: $e');
    }
  }

  /// Get booking by ID
  Future<BookingModel> getBookingById(String bookingId) async {
    try {
      final response = await _supabase
          .from('events_bookings')
          .select('''
            *,
            events(id, name)
          ''')
          .eq('id', bookingId)
          .single();

      return _bookingFromJson(response);
    } catch (e) {
      throw Exception('Failed to fetch booking: $e');
    }
  }

  /// Get check-in statistics for an event
  Future<Map<String, dynamic>> getCheckInStats(String eventId) async {
    try {
      final bookings = await getEventBookings(eventId);

      final total = bookings.length;
      final checkedIn = bookings.where((b) => b.checkedIn).length;
      final pending = total - checkedIn;
      final totalRevenue = bookings.fold<double>(
        0.0,
        (sum, booking) => sum + booking.totalAmount,
      );
      final paidRevenue = bookings.fold<double>(
        0.0,
        (sum, booking) => sum + booking.paidAmount,
      );

      return {
        'total_bookings': total,
        'checked_in': checkedIn,
        'pending': pending,
        'total_revenue': totalRevenue,
        'paid_revenue': paidRevenue,
        'check_in_percentage': total > 0 ? (checkedIn / total * 100).toStringAsFixed(1) : '0',
      };
    } catch (e) {
      throw Exception('Failed to get check-in stats: $e');
    }
  }

  /// Cancel a booking
  Future<BookingModel> cancelBooking(String bookingId, String reason) async {
    try {
      final now = DateTime.now();
      final response = await _supabase
          .from('events_bookings')
          .update({
            'status': BookingStatus.cancelled.name,
            'notes': reason,
            'updated_at': now.toIso8601String(),
          })
          .eq('id', bookingId)
          .select('''
            *,
            events(id, name)
          ''')
          .single();

      return _bookingFromJson(response);
    } catch (e) {
      throw Exception('Failed to cancel booking: $e');
    }
  }

  /// Undo check-in (in case of mistake)
  Future<BookingModel> undoCheckIn(String bookingId) async {
    try {
      final now = DateTime.now();
      final response = await _supabase
          .from('events_bookings')
          .update({
            'checked_in': false,
            'checked_in_at': null,
            'checked_in_by': null,
            'status': BookingStatus.confirmed.name,
            'updated_at': now.toIso8601String(),
          })
          .eq('id', bookingId)
          .select('''
            *,
            events(id, name)
          ''')
          .single();

      return _bookingFromJson(response);
    } catch (e) {
      throw Exception('Failed to undo check-in: $e');
    }
  }

  /// Search bookings by customer name or email
  Future<List<BookingModel>> searchBookings(String eventId, String query) async {
    try {
      final response = await _supabase
          .from('events_bookings')
          .select('''
            *,
            events(id, name)
          ''')
          .eq('event_id', eventId)
          .or('customer_name.ilike.%$query%,customer_email.ilike.%$query%')
          .order('created_at', ascending: false);

      return (response as List).map((json) => _bookingFromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to search bookings: $e');
    }
  }

  /// Helper method to convert JSON to BookingModel
  BookingModel _bookingFromJson(Map<String, dynamic> json) {
    return BookingModel(
      id: json['id'],
      eventId: json['event_id'],
      eventName: json['events'] != null ? json['events']['name'] : null,
      userId: json['user_id'],
      customerName: json['customer_name'],
      customerEmail: json['customer_email'],
      customerPhone: json['customer_phone'],
      bookingType: _parseBookingType(json['booking_type']),
      status: _parseBookingStatus(json['status']),
      quantity: json['quantity'] ?? 1,
      totalAmount: (json['total_amount'] ?? 0).toDouble(),
      paidAmount: (json['paid_amount'] ?? 0).toDouble(),
      ticketCode: json['ticket_code'],
      qrCode: json['qr_code'],
      checkedIn: json['checked_in'] ?? false,
      checkedInAt: json['checked_in_at'] != null
          ? DateTime.parse(json['checked_in_at'])
          : null,
      checkedInBy: json['checked_in_by'],
      notes: json['notes'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  BookingType _parseBookingType(String? type) {
    if (type == null) return BookingType.ticket;
    try {
      return BookingType.values.firstWhere((e) => e.name == type);
    } catch (_) {
      return BookingType.ticket;
    }
  }

  BookingStatus _parseBookingStatus(String? status) {
    if (status == null) return BookingStatus.pending;
    try {
      return BookingStatus.values.firstWhere((e) => e.name == status);
    } catch (_) {
      return BookingStatus.pending;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
