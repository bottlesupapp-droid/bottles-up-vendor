import 'package:supabase_flutter/supabase_flutter.dart';

enum TicketSource { event, table }

class UnifiedTicket {
  final String id;
  final TicketSource source;
  final String ticketCode;
  final String guestName;
  final String guestEmail;
  final String? guestPhone;
  final String title;
  final String venueName;
  final int quantity;
  final double totalAmount;
  final String status;
  final bool checkedIn;
  final DateTime? checkedInAt;
  final String? checkedInBy;
  final DateTime? expiresAt;
  final DateTime createdAt;

  const UnifiedTicket({
    required this.id,
    required this.source,
    required this.ticketCode,
    required this.guestName,
    required this.guestEmail,
    this.guestPhone,
    required this.title,
    required this.venueName,
    required this.quantity,
    required this.totalAmount,
    required this.status,
    required this.checkedIn,
    this.checkedInAt,
    this.checkedInBy,
    this.expiresAt,
    required this.createdAt,
  });

  bool get isExpired =>
      expiresAt != null && DateTime.now().isAfter(expiresAt!);

  bool get isCheckable =>
      status == 'confirmed' && !checkedIn && !isExpired;

  String get sourceLabel =>
      source == TicketSource.event ? 'Event Ticket' : 'Table Reservation';

  UnifiedTicket copyWith({
    bool? checkedIn,
    DateTime? checkedInAt,
    String? checkedInBy,
    String? status,
  }) =>
      UnifiedTicket(
        id: id,
        source: source,
        ticketCode: ticketCode,
        guestName: guestName,
        guestEmail: guestEmail,
        guestPhone: guestPhone,
        title: title,
        venueName: venueName,
        quantity: quantity,
        totalAmount: totalAmount,
        status: status ?? this.status,
        checkedIn: checkedIn ?? this.checkedIn,
        checkedInAt: checkedInAt ?? this.checkedInAt,
        checkedInBy: checkedInBy ?? this.checkedInBy,
        expiresAt: expiresAt,
        createdAt: createdAt,
      );
}

/// Handles ticket lookup and check-in for both event bookings and club table reservations.
/// Ownership is verified against the current vendor's auth ID.
class CheckInService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Find a ticket by its code. Searches events_bookings first, then table_bookings.
  /// Pass [eventId] to restrict search to a specific event.
  Future<UnifiedTicket?> findByCode(String code, {String? eventId}) async {
    final vendorId = _client.auth.currentUser?.id;
    if (vendorId == null) throw Exception('Not authenticated');

    // Search events_bookings
    try {
      var q = _client.from('events_bookings').select('''
        id, ticket_code, status, checked_in, checked_in_at, checked_in_by,
        expires_at, created_at, ticket_quantity, quantity, total_amount,
        customer_name, customer_email, customer_phone,
        events!inner(id, name, user_id, clubs(name))
      ''').eq('ticket_code', code).eq('events.user_id', vendorId);
      if (eventId != null) q = q.eq('event_id', eventId);

      final ev = await q.maybeSingle();
      if (ev != null) {
        final event = ev['events'] as Map<String, dynamic>? ?? {};
        final club = event['clubs'] as Map<String, dynamic>?;
        return UnifiedTicket(
          id: ev['id'] as String,
          source: TicketSource.event,
          ticketCode: ev['ticket_code'] as String? ?? code,
          guestName: ev['customer_name'] as String? ?? 'Guest',
          guestEmail: ev['customer_email'] as String? ?? '',
          guestPhone: ev['customer_phone'] as String?,
          title: event['name'] as String? ?? 'Event',
          venueName: club?['name'] as String? ?? 'Venue',
          quantity: (ev['ticket_quantity'] as int?) ??
              (ev['quantity'] as int?) ??
              1,
          totalAmount: (ev['total_amount'] as num?)?.toDouble() ?? 0.0,
          status: ev['status'] as String? ?? 'pending',
          checkedIn: ev['checked_in'] as bool? ?? false,
          checkedInAt: _dt(ev['checked_in_at']),
          checkedInBy: ev['checked_in_by'] as String?,
          expiresAt: _dt(ev['expires_at']),
          createdAt: DateTime.parse(ev['created_at'] as String),
        );
      }
    } catch (_) {}

    // Search table_bookings (not applicable when scoped to an event)
    if (eventId == null) {
      try {
        final tb = await _client.from('table_bookings').select('''
          id, ticket_code, status, checked_in, checked_in_at, checked_in_by,
          expires_at, created_at, guest_count, total_price,
          contact_phone, contact_email,
          club_tables!inner(name, clubs!inner(name, owner_id))
        ''').eq('ticket_code', code).maybeSingle();

        if (tb != null) {
          final tableRow = tb['club_tables'] as Map<String, dynamic>? ?? {};
          final club = tableRow['clubs'] as Map<String, dynamic>? ?? {};
          if (club['owner_id'] != vendorId) return null;

          return UnifiedTicket(
            id: tb['id'] as String,
            source: TicketSource.table,
            ticketCode: tb['ticket_code'] as String? ?? code,
            guestName: tb['contact_email'] as String? ?? 'Guest',
            guestEmail: tb['contact_email'] as String? ?? '',
            guestPhone: tb['contact_phone'] as String?,
            title: '${club['name'] ?? 'Club'} — ${tableRow['name'] ?? 'Table'}',
            venueName: club['name'] as String? ?? 'Club',
            quantity: tb['guest_count'] as int? ?? 1,
            totalAmount: (tb['total_price'] as num?)?.toDouble() ?? 0.0,
            status: tb['status'] as String? ?? 'pending',
            checkedIn: tb['checked_in'] as bool? ?? false,
            checkedInAt: _dt(tb['checked_in_at']),
            checkedInBy: tb['checked_in_by'] as String?,
            expiresAt: _dt(tb['expires_at']),
            createdAt: DateTime.parse(tb['created_at'] as String),
          );
        }
      } catch (_) {}
    }

    return null;
  }

  /// Check in a ticket. Validates ownership, expiry, and booking status.
  Future<UnifiedTicket> checkIn(String code, {String? eventId}) async {
    final ticket = await findByCode(code, eventId: eventId);

    if (ticket == null) throw Exception('Ticket not found');
    if (ticket.isExpired) throw Exception('Ticket has expired');
    if (ticket.status == 'cancelled') throw Exception('Booking was cancelled');
    if (ticket.checkedIn) {
      final when = ticket.checkedInAt != null
          ? ' at ${_fmtDate(ticket.checkedInAt!)}'
          : '';
      throw Exception('Already checked in$when');
    }
    if (ticket.status != 'confirmed') {
      throw Exception(
          'Cannot check in — status is "${ticket.status}"');
    }

    final now = DateTime.now();
    final vendorId = _client.auth.currentUser!.id;

    if (ticket.source == TicketSource.event) {
      await _client.from('events_bookings').update({
        'checked_in': true,
        'checked_in_at': now.toIso8601String(),
        'checked_in_by': vendorId,
        'status': 'checkedIn',
        'updated_at': now.toIso8601String(),
      }).eq('id', ticket.id);
    } else {
      await _client.from('table_bookings').update({
        'checked_in': true,
        'checked_in_at': now.toIso8601String(),
        'checked_in_by': vendorId,
        'updated_at': now.toIso8601String(),
      }).eq('id', ticket.id);
    }

    return ticket.copyWith(
      checkedIn: true,
      checkedInAt: now,
      checkedInBy: vendorId,
      status: ticket.source == TicketSource.event ? 'checkedIn' : ticket.status,
    );
  }

  /// Undo a mistaken check-in (reverts to confirmed / removes checked_in flag).
  Future<void> undoCheckIn(UnifiedTicket ticket) async {
    if (!ticket.checkedIn) throw Exception('Ticket was not checked in');
    final table = ticket.source == TicketSource.event
        ? 'events_bookings'
        : 'table_bookings';
    await _client.from(table).update({
      'checked_in': false,
      'checked_in_at': null,
      'checked_in_by': null,
      if (ticket.source == TicketSource.event) 'status': 'confirmed',
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', ticket.id);
  }

  DateTime? _dt(dynamic v) =>
      v == null ? null : DateTime.tryParse(v as String);

  String _fmtDate(DateTime dt) =>
      '${dt.day}/${dt.month}/${dt.year} '
      '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
}
