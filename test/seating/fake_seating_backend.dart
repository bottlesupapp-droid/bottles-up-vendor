import 'package:bottles_up_vendor/features/seating/services/seating_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

PostgrestException refuse(String message) => PostgrestException(message: message, code: 'P0001');

class FakeSeatBooking {
  FakeSeatBooking(this.id, this.code, this.name, {this.table = 'VIP booth', this.guests = 4, this.start = '21:00:00', this.owner = 'me', this.status = 'paid'});

  final String id;
  final String code;
  final String name;
  final String table;
  final int guests;
  final String start;

  /// 'me', 'other' or null (nobody's table).
  final String? owner;
  final String status;
  bool seated = false;
  DateTime? seatedAt;
  String? method;
  String? confirmation;
  int? estimate;
  String? seatedBy;
}

class FakeMessage {
  FakeMessage(this.bookingId, this.kind, {this.status = 'queued', this.error});

  final String bookingId;
  final String kind;
  String status;
  String? error;
}

/// The database's seating functions, as a fake with the same sentences the SQL raises. [role] is who is signed in: a server reaches only
/// the tables given to them, a manager every paid table of the night.
class FakeSeatingBackend {
  FakeSeatingBackend({this.role = 'server'});

  String role;
  final List<FakeSeatBooking> bookings = [];
  final List<FakeMessage> outbox = [];
  final List<({String function, Map<String, dynamic>? params})> calls = [];
  bool offline = false;
  bool missing = false;

  /// Make every search result say the caller cannot seat it (as a table that belongs to someone else would, for a manager's colleague).
  bool cannotSeat = false;
  DateTime now = DateTime(2026, 10, 9, 21, 42);

  bool get _manager => role == 'manager' || role == 'owner';
  bool _canAct(FakeSeatBooking b) => _manager || b.owner == 'me';

  List<Map<String, dynamic>> calledWith(String function) => [
        for (final c in calls)
          if (c.function == function) c.params ?? const {},
      ];

  FakeSeatBooking _find(Object? id) {
    final b = bookings.where((b) => b.id == id).firstOrNull;
    if (b == null) throw refuse('not allowed');
    return b;
  }

  Future<dynamic> call(String function, {Map<String, dynamic>? params}) async {
    calls.add((function: function, params: params));
    if (offline) throw Exception('SocketException: connection lost');
    if (missing) throw PostgrestException(message: 'function $function does not exist', code: '42883');
    switch (function) {
      case 'desk_find_booking':
        {
          final q = (params!['p_query'] as String).trim();
          if (q.length < 3) throw refuse('type at least 3 letters of the name, or the booking code');
          return [
            for (final b in bookings)
              if (b.status == 'paid' && (_manager || b.owner == 'me') && (b.code.toLowerCase() == q.toLowerCase() || b.name.toLowerCase().contains(q.toLowerCase())))
                {
                  'booking_id': b.id,
                  'confirmation_code': b.code,
                  'customer_name': b.name,
                  'table_name': b.table,
                  'guest_count': b.guests,
                  'start_time': b.start,
                  'seated': b.seated,
                  'server_name': b.owner == 'other' ? 'Bea Server' : (b.owner == 'me' ? 'Me Myself' : null),
                  'is_mine': b.owner == 'me',
                  'can_seat': !cannotSeat && _canAct(b),
                },
          ];
        }
      case 'desk_mark_seated':
        {
          final b = _find(params!['p_booking']);
          if (!_canAct(b)) throw refuse('not allowed');
          final method = params['p_method'] as String?;
          if (method != 'scan' && method != 'manual') throw refuse('choose scan or manual');
          final detail = (params['p_confirmation'] as String?)?.trim();
          if (method == 'manual' && (detail == null || detail.length < 3)) throw refuse('say what you checked with the guest');
          final est = params['p_estimate_minutes'] as int?;
          if (est != null && (est < 1 || est > 480)) throw refuse('the estimate is between 1 and 480 minutes');
          if (b.status != 'paid') throw refuse('only a paid booking can be seated');
          if (b.seated) return {'already': true, 'seated_at': b.seatedAt?.toIso8601String(), 'estimate_minutes': b.estimate};
          b
            ..seated = true
            ..seatedAt = now
            ..method = method
            ..confirmation = detail
            ..estimate = est
            ..seatedBy = 'Me Myself';
          outbox.add(FakeMessage(b.id, 'seated_ack'));
          return {'already': false, 'seated_at': now.toIso8601String(), 'estimate_minutes': est};
        }
      case 'desk_set_estimate':
        {
          final b = _find(params!['p_booking']);
          if (!_canAct(b)) throw refuse('not allowed');
          final minutes = params['p_minutes'] as int?;
          if (minutes != null && (minutes < 1 || minutes > 480)) throw refuse('the estimate is between 1 and 480 minutes');
          if (!b.seated) throw refuse('seat the guest first');
          if (b.estimate == minutes) return {'changed': false, 'estimate_minutes': b.estimate};
          b.estimate = minutes;
          if (minutes != null) outbox.add(FakeMessage(b.id, 'estimate_updated'));
          return {'changed': true, 'estimate_minutes': minutes};
        }
      case 'desk_unseat':
        {
          final b = _find(params!['p_booking']);
          if (!_manager) throw refuse('not allowed');
          final reason = (params['p_reason'] as String?)?.trim() ?? '';
          if (reason.length < 3) throw refuse('say why this guest is being un-seated');
          if (!b.seated) throw refuse('this guest is not seated');
          b
            ..seated = false
            ..seatedAt = null
            ..method = null
            ..confirmation = null
            ..estimate = null;
          return null;
        }
      case 'desk_booking_seating':
        {
          final b = _find(params!['p_booking']);
          if (!_canAct(b)) throw refuse('not allowed');
          return [
            {
              'seated': b.seated,
              'seated_at': b.seatedAt?.toIso8601String(),
              'method': b.method,
              'estimate_minutes': b.estimate,
              'seated_by_name': b.seatedBy,
              'confirmation': b.confirmation,
            },
          ];
        }
      case 'desk_booking_messages':
        {
          final b = _find(params!['p_booking']);
          if (!_canAct(b)) throw refuse('not allowed');
          return [
            for (final m in outbox.where((m) => m.bookingId == b.id))
              {'kind': m.kind, 'status': m.status, 'created_at': now.toIso8601String(), 'sent_at': null, 'last_error': m.error},
          ];
        }
    }
    throw StateError('unexpected call $function');
  }

  SeatingService get service => SeatingService(caller: call);
}
