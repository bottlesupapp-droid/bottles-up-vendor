import 'dart:async';

import 'package:bottles_up_vendor/features/server_desk/services/server_desk_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

PostgrestException refuse(String message) => PostgrestException(message: message, code: 'P0001');

class FakeBooking {
  FakeBooking(
    this.id, {
    this.venueId = 'v1',
    this.night = '2026-10-09',
    this.startTime = '21:00:00',
    this.slotLabel,
    this.table = 'VIP booth',
    this.guests = 4,
    this.customer = 'Ada Lovelace',
    this.code,
    this.status = 'paid',
    this.checkedInAt,
  });

  final String id;
  String venueId;
  String night;
  String startTime;
  String? slotLabel;
  String table;
  int guests;
  String customer;
  String? code;
  String status;
  String? checkedInAt;
}

class FakeRequest {
  FakeRequest(this.id, this.bookingId, this.kind, this.createdAt, {this.note, this.status = 'new', this.assigned});

  final String id;
  final String bookingId;
  final String kind;
  final String? note;
  String status;
  String? assigned;
  String? statusNote;
  final DateTime createdAt;
  DateTime? acknowledgedAt;
  DateTime? closedAt;
}

/// A stand-in for the website's server-desk functions that behaves the way they do (website repo, 20261014100000_table_servers.sql
/// and 20261014110000_service_requests.sql): who may call what, which requests a server can see, the first to acknowledge owning a
/// request, a repeated ask being one request, the reasons the database insists on, and its own sentences, raised as P0001. A test
/// compares every sentence it raises with the SQL, so the two cannot drift apart unnoticed.
class FakeDeskBackend {
  final List<(String, Map<String, dynamic>?)> calls = [];

  /// The caller: 'server', 'manager' (a manager or the owner), or 'none'. The memberships they hold, and the one a request they
  /// take is recorded against.
  String level = 'server';
  Set<String> myMemberships = {'m-me'};
  String myPrimary = 'm-me';

  /// Server memberships of the club the manager can give a table to: membership id -> 'ok' | 'revoked' | 'ended' | 'other-club' | 'door'.
  final Map<String, String> staff = {'m-me': 'ok'};

  DateTime now = DateTime.utc(2026, 10, 9, 22);

  final Map<String, FakeBooking> bookings = {};
  final Map<String, String> assignments = {};
  final Map<String, DateTime> assignedAt = {};
  final List<FakeRequest> requests = [];

  Object? failAll;

  /// Functions that fail (the others work), to see a screen cope with one missing answer.
  final Map<String, Object> failOn = {};
  void Function(String function)? beforeCall;
  Future<void>? hold;

  int _next = 1;
  String id(String p) => '$p${_next++}';

  ServerDeskService get service => ServerDeskService(rpc: call);

  FakeBooking addBooking(String id, {String night = '2026-10-09', String time = '21:00:00', String? label, String table = 'VIP booth', int guests = 4, String name = 'Ada Lovelace', String? code, String status = 'paid', String? checkedInAt, String venue = 'v1'}) {
    return bookings[id] = FakeBooking(id, venueId: venue, night: night, startTime: time, slotLabel: label, table: table, guests: guests, customer: name, code: code, status: status, checkedInAt: checkedInAt);
  }

  FakeRequest addRequest(String bookingId, String kind, {String status = 'new', String? assigned, String? note, DateTime? createdAt, String? rid}) {
    final r = FakeRequest(rid ?? id('r'), bookingId, kind, createdAt ?? now, note: note, status: status, assigned: assigned);
    requests.add(r);
    return r;
  }

  List<Map<String, dynamic>?> get params => [for (final c in calls) c.$2];

  bool get _manager => level == 'manager';

  Future<dynamic> call(String function, {Map<String, dynamic>? params}) async {
    calls.add((function, params));
    final broken = failAll;
    if (broken != null) throw broken;
    final failing = failOn[function];
    if (failing != null) throw failing;
    beforeCall?.call(function);
    final waiting = hold;
    if (waiting != null) await waiting;
    final p = params ?? const {};
    switch (function) {
      case 'my_assigned_tables':
        return _myTables(p);
      case 'list_service_requests':
        return _list(p);
      case 'create_service_request':
        return _create(p);
      case 'update_service_request':
        return _update(p);
      case 'list_venue_booking_servers':
        return _bookingServers(p);
      case 'assign_booking_server':
        return _assign(p);
      case 'unassign_booking_server':
        return _unassign(p);
    }
    throw StateError('unexpected call to $function');
  }

  String? _trim(Object? v) {
    final t = (v as String?)?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }

  void _needLevel(String venue) {
    if (level == 'none' || venue != 'v1') throw refuse('not allowed');
  }

  void _needEditor(String venue) {
    if (!_manager || venue != 'v1') throw refuse('not allowed');
  }

  List<Map<String, dynamic>> _myTables(Map<String, dynamic> p) {
    final night = p['p_night'];
    if (night == null) throw refuse('choose a night');
    final rows = [
      for (final e in assignments.entries)
        if (myMemberships.contains(e.value) && staff[e.value] == 'ok' && bookings[e.key] != null && bookings[e.key]!.status == 'paid' && bookings[e.key]!.night == night) bookings[e.key]!,
    ]..sort((a, b) {
        final t = a.startTime.compareTo(b.startTime);
        return t != 0 ? t : a.customer.compareTo(b.customer);
      });
    return [
      for (final b in rows)
        {
          'booking_id': b.id,
          'venue_id': b.venueId,
          'venue_name': 'Club A',
          'night_date': b.night,
          'start_time': b.startTime,
          'slot_label': b.slotLabel,
          'table_name': b.table,
          'guest_count': b.guests,
          'customer_name': b.customer,
          'confirmation_code': b.code,
          'checked_in_at': b.checkedInAt,
          'assigned_at': assignedAt[b.id]?.toIso8601String(),
        },
    ];
  }

  Map<String, dynamic> _row(FakeRequest r) {
    final b = bookings[r.bookingId]!;
    return {
      'request_id': r.id,
      'booking_id': r.bookingId,
      'confirmation_code': b.code,
      'customer_name': b.customer,
      'table_name': b.table,
      'guest_count': b.guests,
      'kind': r.kind,
      'note': r.note,
      'source': 'staff',
      'status': r.status,
      'assigned_membership_id': r.assigned,
      'assigned_to_me': r.assigned != null && myMemberships.contains(r.assigned),
      'created_at': r.createdAt.toIso8601String(),
      'acknowledged_at': r.acknowledgedAt?.toIso8601String(),
      'closed_at': r.closedAt?.toIso8601String(),
      'status_note': r.statusNote,
    };
  }

  bool _open(FakeRequest r) => r.status != 'completed' && r.status != 'cancelled';

  List<Map<String, dynamic>> _list(Map<String, dynamic> p) {
    _needLevel(p['p_venue'] as String);
    final includeClosed = p['p_include_closed'] == true;
    final rows = [
      for (final r in requests)
        if (bookings[r.bookingId]?.venueId == p['p_venue'] &&
            (_open(r) || (includeClosed && r.closedAt != null && r.closedAt!.isAfter(now.subtract(const Duration(hours: 24))))) &&
            (_manager || (r.assigned ?? assignments[r.bookingId]) == null || myMemberships.contains(r.assigned ?? assignments[r.bookingId])))
          r,
    ];
    rows.sort((a, b) {
      final ao = _open(a), bo = _open(b);
      if (ao != bo) return ao ? -1 : 1;
      if (ao) return a.createdAt.compareTo(b.createdAt);
      return b.closedAt!.compareTo(a.closedAt!);
    });
    return [for (final r in rows.take(300)) _row(r)];
  }

  String _create(Map<String, dynamic> p) {
    final b = bookings[p['p_booking']];
    if (b == null) throw refuse('not allowed');
    _needLevel(b.venueId);
    const kinds = ['assistance', 'water_ice_mixers', 'order_question', 'bill_request', 'table_issue'];
    final kind = p['p_kind'];
    if (kind == null || !kinds.contains(kind)) throw refuse('choose what the table needs');
    final note = _trim(p['p_note']);
    if (note != null && note.length > 300) throw refuse('keep the note to 300 characters or fewer');
    if (b.status != 'paid') throw refuse('only a paid booking can have service requests');
    final server = assignments[b.id];
    if (level == 'server' && server != null && !myMemberships.contains(server)) throw refuse('this table belongs to another server');
    final existing = requests.where((r) => r.bookingId == b.id && r.kind == kind && _open(r)).firstOrNull;
    if (existing != null) return existing.id;
    return addRequest(b.id, kind as String, note: note, assigned: server).id;
  }

  dynamic _update(Map<String, dynamic> p) {
    final action = p['p_action'];
    const actions = ['acknowledge', 'start', 'complete', 'escalate', 'cancel', 'reassign'];
    if (action == null || !actions.contains(action)) throw refuse('unknown action');
    final req = requests.where((r) => r.id == p['p_request']).firstOrNull;
    if (req == null) throw refuse('not allowed');
    final venue = bookings[req.bookingId]!.venueId;
    _needLevel(venue);
    final note = _trim(p['p_note']);
    if (note != null && note.length > 300) throw refuse('keep the note to 300 characters or fewer');

    final handler = req.assigned ?? assignments[req.bookingId];
    final mine = handler != null && myMemberships.contains(handler);
    final free = handler == null;
    final to = {'acknowledge': 'acknowledged', 'start': 'in_progress', 'complete': 'completed', 'escalate': 'escalated', 'cancel': 'cancelled'}[action];

    if (to != null && req.status == to && (_manager || mine)) return null;
    if (!_open(req)) throw refuse('this request is already closed');

    if (action == 'reassign') {
      if (!_manager) throw refuse('only a manager can hand a request to someone else');
      final target = p['p_assignee'] as String?;
      final state = target == null ? null : staff[target];
      if (state == null || state == 'other-club' || state == 'door') throw refuse('that person is not staff at this club');
      if (state != 'ok') throw refuse('that person no longer has access to this club');
      req
        ..assigned = target
        ..status = 'new'
        ..acknowledgedAt = null;
      return null;
    }

    if (req.status == 'escalated' && !_manager) throw refuse('this request was passed to a manager');
    if (!(_manager || mine || free)) {
      throw refuse(req.status == 'new' ? 'this request belongs to another server' : 'someone else has already taken this request');
    }

    switch (action) {
      case 'acknowledge':
        if (req.status != 'new' && req.status != 'escalated') {
          throw refuse(mine ? 'you have already taken this request' : 'someone else has already taken this request');
        }
        req
          ..status = 'acknowledged'
          ..assigned = myPrimary
          ..acknowledgedAt = now;
      case 'start':
        if (req.status != 'acknowledged') throw refuse('acknowledge the request first');
        req.status = 'in_progress';
      case 'complete':
        if (req.status == 'new' || req.status == 'escalated') req.assigned = myPrimary;
        req
          ..status = 'completed'
          ..closedAt = now
          ..statusNote = note ?? req.statusNote
          ..acknowledgedAt ??= now;
      case 'escalate':
        if (note == null) throw refuse('say why you are passing this request to a manager');
        req
          ..status = 'escalated'
          ..statusNote = note
          ..assigned ??= myPrimary;
      default: // cancel
        if (note == null) throw refuse('say why this request is being cancelled');
        req
          ..status = 'cancelled'
          ..closedAt = now
          ..statusNote = note
          ..assigned ??= myPrimary;
    }
    return null;
  }

  List<Map<String, dynamic>> _bookingServers(Map<String, dynamic> p) {
    _needEditor(p['p_venue'] as String);
    if (p['p_from'] == null || p['p_to'] == null) throw refuse('choose a start and an end date');
    if ((p['p_to'] as String).compareTo(p['p_from'] as String) < 0) throw refuse('the end date is before the start date');
    return [
      for (final e in assignments.entries)
        if (bookings[e.key] != null &&
            bookings[e.key]!.venueId == p['p_venue'] &&
            bookings[e.key]!.night.compareTo(p['p_from'] as String) >= 0 &&
            bookings[e.key]!.night.compareTo(p['p_to'] as String) <= 0)
          {
            'booking_id': e.key,
            'membership_id': e.value,
            'user_id': 'u-${e.value}',
            'server_available': staff[e.value] == 'ok',
            'assigned_at': assignedAt[e.key]?.toIso8601String(),
          },
    ];
  }

  dynamic _assign(Map<String, dynamic> p) {
    final bookingId = p['p_booking'];
    final membership = p['p_membership'];
    if (bookingId == null || membership == null) throw refuse('choose a booking and a server');
    final b = bookings[bookingId];
    if (b == null) throw refuse('not allowed');
    _needEditor(b.venueId);
    if (b.status != 'paid') throw refuse('only a paid booking can be given to a server');
    final state = membership == null ? null : staff[membership];
    if (state == null || state == 'other-club' || state == 'door') throw refuse('that person is not a server at this club');
    if (state != 'ok') throw refuse('that person no longer has access to this club');
    if (assignments[b.id] == membership) return null;
    assignments[b.id] = membership as String;
    assignedAt[b.id] = now;
    return null;
  }

  dynamic _unassign(Map<String, dynamic> p) {
    final b = bookings[p['p_booking']];
    if (b == null) throw refuse('not allowed');
    _needEditor(b.venueId);
    assignments.remove(b.id);
    return null;
  }
}
