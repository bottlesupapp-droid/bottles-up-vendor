import 'dart:async';

import 'package:bottles_up_vendor/features/booking_conflicts/services/conflict_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

PostgrestException refuse(String message) => PostgrestException(message: message, code: 'P0001');

class FakeConflict {
  FakeConflict(
    this.id, {
    this.bookingId = 'b1',
    this.venueId = 'v1',
    this.code = 'CF0002',
    this.name = 'Late Payer',
    this.email = 'late@example.com',
    this.phone = '+1 555 0122',
    this.table = 'Last booth',
    this.date = '2026-11-14',
    this.time = '21:00:00',
    this.guests = 2,
    this.paid = 10000,
    this.counted = 2,
    this.available = 1,
    this.status = 'open',
    this.resolution,
    this.note,
    this.bookingStatus = 'paid',
    this.stillOverbooked = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.utc(2026, 11, 14, 21, 40);

  final String id;
  String bookingId;
  String venueId;
  String? code;
  String name;
  String? email;
  String? phone;
  String table;
  String date;
  String time;
  int guests;
  int paid;
  int counted;
  int available;
  String status;
  String? resolution;
  String? note;
  DateTime? resolvedAt;
  DateTime createdAt;

  /// The booking as it is now (the manager may have moved or refunded it since).
  String bookingStatus;
  bool stillOverbooked;
}

/// A stand-in for the website's `desk_booking_conflicts` and `desk_resolve_booking_conflict` (20261113100000_oversold_booking_queue.sql) that behaves the way they do: who may call
/// what, the order of the checks, the facts it checks before a conflict can be closed, and its own sentences, raised as P0001. A test compares every sentence with the SQL.
class FakeConflictBackend {
  /// Every sentence this raises; a drift test checks each one is in the migration.
  static const sentences = [
    'not authenticated',
    'not allowed',
    'say how it was settled: moved, refunded or kept',
    'say what was done, in a few words',
    'keep the note to 500 characters or fewer',
    'this has already been dealt with',
    'the booking is not paid any more: close this as refunded',
    'that table is still double-booked: move the booking to another table first',
    'refund or cancel the booking first',
  ];

  final List<(String, Map<String, dynamic>?)> calls = [];

  /// The caller: 'manager' (a manager or the owner of the club), 'server', or 'none'.
  String level = 'manager';
  bool signedIn = true;
  Object? failAll;
  final Map<String, Object> failOn = {};
  Future<void>? hold;
  final List<FakeConflict> rows = [];
  DateTime now = DateTime.utc(2026, 11, 14, 22);

  BookingConflictService get service => BookingConflictService(caller: call);

  FakeConflict add(String id, {String venue = 'v1', String status = 'open', String? bookingId, String? name, bool overbooked = true, String bookingStatus = 'paid', String? email, String? phone}) {
    final c = FakeConflict(id, venueId: venue, status: status, bookingId: bookingId ?? 'b-$id', name: name ?? 'Guest $id', stillOverbooked: overbooked, bookingStatus: bookingStatus, email: email ?? 'g-$id@example.com', phone: phone ?? '+1 555 0100');
    rows.add(c);
    return c;
  }

  Future<dynamic> call(String function, {Map<String, dynamic>? params}) async {
    calls.add((function, params));
    final broken = failAll;
    if (broken != null) throw broken;
    final failing = failOn[function];
    if (failing != null) throw failing;
    final waiting = hold;
    if (waiting != null) await waiting;
    final p = params ?? const {};
    switch (function) {
      case 'desk_booking_conflicts':
        return _list(p);
      case 'desk_resolve_booking_conflict':
        return _resolve(p);
    }
    throw PostgrestException(message: 'Could not find the function public.$function', code: 'PGRST202');
  }

  List<Map<String, dynamic>> _list(Map<String, dynamic> p) {
    if (!signedIn) throw refuse('not authenticated');
    if (level != 'manager') throw refuse('not allowed');
    final all = p['p_include_resolved'] == true;
    final out = rows.where((c) => c.venueId == p['p_venue'] && (all || c.status == 'open')).toList()
      ..sort((a, b) {
        final byState = (a.status == 'open' ? 0 : 1).compareTo(b.status == 'open' ? 0 : 1);
        return byState != 0 ? byState : b.createdAt.compareTo(a.createdAt);
      });
    return [
      for (final c in out)
        {
          'conflict_id': c.id,
          'booking_id': c.bookingId,
          'confirmation_code': c.code,
          'customer_name': c.name,
          'customer_email': c.email,
          'customer_phone': c.phone,
          'table_name': c.table,
          'arrival_date': c.date,
          'arrival_time': c.time,
          'guest_count': c.guests,
          'amount_paid_cents': c.paid,
          'currency': 'cad',
          'tables_counted': c.counted,
          'tables_available': c.available,
          'status': c.status,
          'resolution': c.resolution,
          'resolution_note': c.note,
          'created_at': c.createdAt.toIso8601String(),
          'resolved_at': c.resolvedAt?.toIso8601String(),
        },
    ];
  }

  dynamic _resolve(Map<String, dynamic> p) {
    if (!signedIn) throw refuse('not authenticated');
    final c = rows.where((r) => r.id == p['p_conflict']).firstOrNull;
    if (c == null) throw refuse('not allowed');
    if (level != 'manager') throw refuse('not allowed');
    final how = p['p_resolution'];
    final note = (p['p_note'] as String?)?.trim();
    if (how == null || !['moved', 'refunded', 'kept'].contains(how)) throw refuse('say how it was settled: moved, refunded or kept');
    if (note == null || note.length < 3) throw refuse('say what was done, in a few words');
    if (note.length > 500) throw refuse('keep the note to 500 characters or fewer');
    if (c.status != 'open') throw refuse('this has already been dealt with');
    if (how == 'moved') {
      if (c.bookingStatus != 'paid') throw refuse('the booking is not paid any more: close this as refunded');
      if (c.stillOverbooked) throw refuse('that table is still double-booked: move the booking to another table first');
    } else if (how == 'refunded') {
      if (!['refunded', 'cancelled'].contains(c.bookingStatus)) throw refuse('refund or cancel the booking first');
    }
    c
      ..status = 'resolved'
      ..resolution = how as String
      ..note = note
      ..resolvedAt = now;
    return null;
  }
}

/// The error PostgREST gives when a function does not exist yet (the migration is not applied).
class PostgrestExceptionFor {
  static PostgrestException missing() => PostgrestException(message: 'Could not find the function public.desk_booking_conflicts', code: 'PGRST202');
}
