import 'package:bottles_up_vendor/features/table_map/services/table_map_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

PostgrestException refuse(String message) => PostgrestException(message: message, code: 'P0001');

/// The website's floor, table-state, move and deposit-terms functions (20261021100000_floor_plan_and_table_states.sql) as a fake with the same checks, in the same order,
/// and the same sentences: only a manager of the club may block, reopen or move; the reason and the quantity are checked; only tables that are free are blocked; a booking is
/// moved only when the party fits and a table is free; a deposit's purpose has to agree with the credit switch. Counts come from the bookings and blocks, so a table
/// taken in the meantime is gone. Ids: slots s1.., tables t1.., floors f1.., bookings bk1.., blocks blk1..
class FakeTableMapBackend {
  String role = 'manager';

  /// The BottlesUp-owned switch: the deposit counts toward the bottle bill.
  bool depositIsCredit = false;

  /// What the venue chose (null = nothing chosen yet).
  Map<String, dynamic>? depositTerms;

  /// Arrival times: id, start_time, label.
  final List<Map<String, dynamic>> slots = [
    {'id': 's1', 'start_time': '21:00:00', 'label': null},
    {'id': 's2', 'start_time': '23:30:00', 'label': 'Late'},
  ];

  /// Table types.
  final List<Map<String, dynamic>> tables = [
    {'id': 't1', 'name': 'Booth', 'max_guests': 6, 'min_guests': null, 'inventory': 1, 'deposit_cents': 10000, 'pricing_mode': 'flat', 'floor_id': 'f1', 'pos_x': 10.0, 'pos_y': 20.0, 'width': 12.0, 'height': 10.0, 'included_admissions': null},
    {'id': 't2', 'name': 'Pair table', 'max_guests': 4, 'min_guests': 2, 'inventory': 3, 'deposit_cents': 2500, 'pricing_mode': 'flat', 'floor_id': null, 'pos_x': null, 'pos_y': null, 'width': null, 'height': null, 'included_admissions': 2},
    {'id': 't3', 'name': 'Sofa', 'max_guests': 8, 'min_guests': null, 'inventory': 2, 'deposit_cents': 0, 'pricing_mode': 'hourly', 'floor_id': null, 'pos_x': null, 'pos_y': null, 'width': null, 'height': null, 'included_admissions': null},
  ];

  /// Bookings: id, table, slot, guests, status ('paid' or 'pending'), seated (true = occupied).
  final List<Map<String, dynamic>> bookings = [];
  final List<Map<String, dynamic>> blocks = [];
  final List<Map<String, dynamic>> moves = [];
  final List<(String, Map<String, dynamic>?)> calls = [];
  DateTime Function() now = DateTime.now;
  int _next = 0;

  Object? failAll;
  Object? failStates;
  Object? failBlock;
  Object? failMove;
  Object? failLayout;
  void Function(String function)? beforeCall;
  Future<void>? hold;

  TableMapService get service => TableMapService(caller: call);

  List<Map<String, dynamic>> paramsOf(String function) => [for (final c in calls) if (c.$1 == function) c.$2 ?? const {}];

  String id(String prefix) => '$prefix${++_next}';

  Map<String, dynamic> addBooking({String table = 't1', String slot = 's1', int guests = 2, String status = 'paid', bool seated = false, String name = 'Ann Guest'}) {
    final b = {'id': id('bk'), 'table': table, 'slot': slot, 'guests': guests, 'status': status, 'seated': seated, 'name': name};
    bookings.add(b);
    return b;
  }

  Map<String, dynamic> table(String idOf) => tables.firstWhere((t) => t['id'] == idOf);

  bool _active(Map<String, dynamic> b) => b['released'] != true && (b['expires'] == null || (b['expires'] as DateTime).isAfter(now()));

  int _blocked(String table, String slot, {String? kind}) => blocks
      .where((b) => b['table'] == table && b['slot'] == slot && _active(b) && (kind == null || b['kind'] == kind))
      .fold(0, (a, b) => a + (b['quantity'] as int));

  int _paid(String table, String slot, {bool? seated}) =>
      bookings.where((b) => b['table'] == table && b['slot'] == slot && b['status'] == 'paid' && (seated == null || b['seated'] == seated)).length;

  /// Paid bookings + blocks in force (checkouts in progress are not modelled here).
  int taken(String table, String slot) => _paid(table, slot) + _blocked(table, slot);

  Future<dynamic> call(String function, {Map<String, dynamic>? params}) async {
    calls.add((function, params));
    final broken = failAll;
    if (broken != null) throw broken;
    beforeCall?.call(function);
    final waiting = hold;
    if (waiting != null) await waiting;
    final p = params ?? const {};
    if (role == 'none') throw refuse('not authenticated');
    switch (function) {
      case 'desk_table_states':
        final broken = failStates;
        if (broken != null) throw broken;
        _manager();
        return [
          for (final s in slots)
            for (final t in tables)
              {
                'slot_id': s['id'],
                'start_time': s['start_time'],
                'slot_label': s['label'],
                'table_type_id': t['id'],
                'table_name': t['name'],
                'max_guests': t['max_guests'],
                'floor_id': t['floor_id'],
                'pos_x': t['pos_x'],
                'pos_y': t['pos_y'],
                'width': t['width'],
                'height': t['height'],
                'inventory': t['inventory'],
                'booked': _paid(t['id'] as String, s['id'] as String, seated: false),
                'occupied': _paid(t['id'] as String, s['id'] as String, seated: true),
                'held': _blocked(t['id'] as String, s['id'] as String, kind: 'held'),
                'unavailable': _blocked(t['id'] as String, s['id'] as String, kind: 'unavailable'),
                'available': ((t['inventory'] as int) - taken(t['id'] as String, s['id'] as String)).clamp(0, 1000),
              },
        ];
      case 'desk_table_blocks':
        _manager();
        return [
          for (final b in blocks)
            if (_active(b))
              {
                'block_id': b['id'],
                'table_type_id': b['table'],
                'table_name': table(b['table'] as String)['name'],
                'slot_id': b['slot'],
                'start_time': slots.firstWhere((s) => s['id'] == b['slot'])['start_time'],
                'kind': b['kind'],
                'quantity': b['quantity'],
                'reason': b['reason'],
                'made_by': 'Mo Manager',
                'made_at': now().toIso8601String(),
                'expires_at': (b['expires'] as DateTime?)?.toUtc().toIso8601String(),
              },
        ];
      case 'desk_table_block':
        final broken = failBlock;
        if (broken != null) throw broken;
        _manager();
        final kind = p['p_kind'] as String?;
        final reason = ((p['p_reason'] as String?) ?? '').trim();
        final qty = p['p_quantity'] as int?;
        final minutes = p['p_minutes'] as int?;
        if (kind == null || (kind != 'held' && kind != 'unavailable')) throw refuse('choose hold or unavailable');
        if (reason.length < 3 || reason.length > 200) throw refuse('give a reason of 3 to 200 characters');
        if (qty == null || qty < 1 || qty > 500) throw refuse('how many tables?');
        if (kind == 'held' && (minutes == null || minutes < 5 || minutes > 1440)) throw refuse('a hold lasts between 5 minutes and 24 hours');
        if (kind == 'unavailable' && minutes != null) throw refuse('a table that is unavailable stays so until it is reopened, so it has no time limit');
        final t = tables.where((x) => x['id'] == p['p_type']).firstOrNull;
        if (t == null) throw refuse('table not found');
        final s = slots.where((x) => x['id'] == p['p_slot']).firstOrNull;
        if (s == null) throw refuse('arrival time not found');
        final free = (t['inventory'] as int) - taken(t['id'] as String, s['id'] as String);
        if (qty > free) throw refuse('only ${free < 0 ? 0 : free} of these tables are free for that time; tables that are already booked or held cannot be blocked');
        final blockId = id('blk');
        blocks.add({'id': blockId, 'table': t['id'], 'slot': s['id'], 'kind': kind, 'quantity': qty, 'reason': reason, 'expires': kind == 'held' ? now().add(Duration(minutes: minutes!)) : null, 'released': false});
        return {'block_id': blockId, 'free_after': free - qty};
      case 'desk_table_release':
        _manager();
        final b = blocks.where((x) => x['id'] == p['p_block']).firstOrNull;
        if (b == null) throw refuse('not allowed');
        if (!_active(b)) return false;
        b['released'] = true;
        return true;
      case 'desk_booking_move_options':
        _manager();
        final bk = _booking(p['p_booking']);
        final from = table(bk['table'] as String);
        return [
          for (final t in tables)
            {
              'table_type_id': t['id'],
              'table_name': t['name'],
              'max_guests': t['max_guests'],
              'min_guests': t['min_guests'],
              'available': ((t['inventory'] as int) - taken(t['id'] as String, bk['slot'] as String)).clamp(0, 1000),
              'fits': (bk['guests'] as int) <= (t['max_guests'] as int) && (t['min_guests'] == null || (bk['guests'] as int) >= (t['min_guests'] as int)),
              'is_current': t['id'] == bk['table'],
              'price_difference_cents': from['pricing_mode'] == 'flat' && t['pricing_mode'] == 'flat' ? (t['deposit_cents'] as int) - (from['deposit_cents'] as int) : null,
            },
        ];
      case 'desk_move_booking':
        final broken = failMove;
        if (broken != null) throw broken;
        _manager();
        final reason = ((p['p_reason'] as String?) ?? '').trim();
        if (reason.length < 3 || reason.length > 200) throw refuse('give a reason of 3 to 200 characters');
        final bk = _booking(p['p_booking']);
        if (bk['status'] != 'paid') throw refuse('only a confirmed booking can be moved');
        if (bk['table'] == p['p_to_type']) throw refuse('the booking is already at that table');
        final from = table(bk['table'] as String);
        final to = tables.where((x) => x['id'] == p['p_to_type']).firstOrNull;
        if (to == null) throw refuse('table not found');
        final guests = bk['guests'] as int;
        if (guests > (to['max_guests'] as int)) throw refuse('that table seats up to ${to['max_guests']} guests and this booking has $guests');
        if (to['min_guests'] != null && guests < (to['min_guests'] as int)) throw refuse('that table needs at least ${to['min_guests']} guests and this booking has $guests');
        if (taken(to['id'] as String, bk['slot'] as String) >= (to['inventory'] as int)) throw refuse('no tables of that type are free for that time');
        final diff = from['pricing_mode'] == 'flat' && to['pricing_mode'] == 'flat' ? (to['deposit_cents'] as int) - (from['deposit_cents'] as int) : null;
        bk['table'] = to['id'];
        final moveId = id('mv');
        moves.insert(0, {'id': moveId, 'booking': bk['id'], 'from': from['name'], 'to': to['name'], 'reason': reason, 'diff': diff, 'at': now().toUtc().toIso8601String()});
        return {'move_id': moveId, 'from': from['name'], 'to': to['name'], 'price_difference_cents': diff};
      case 'desk_booking_moves':
        _manager();
        _booking(p['p_booking']);
        return [
          for (final m in moves)
            if (m['booking'] == p['p_booking']) {'moved_at': m['at'], 'from_table': m['from'], 'to_table': m['to'], 'moved_by': 'Mo Manager', 'reason': m['reason'], 'price_difference_cents': m['diff']},
        ];
      case 'desk_booking_terms':
        if (role != 'manager' && role != 'server') throw refuse('not allowed');
        final bk = _booking(p['p_booking']);
        final t = table(bk['table'] as String);
        return {
          'deposit_cents': t['deposit_cents'],
          'deposit_terms': depositTerms ?? {'recipient': 'venue', 'venue_pct': 100, 'purpose': depositIsCredit ? 'minimum_spend_credit' : 'reservation_fee', 'default': true},
          'included_admissions': t['included_admissions'],
          'refund_policy_set': true,
          'refund_policy_lines': ['Full refund up to 48 hours before', '50% back up to 24 hours before'],
        };
      case 'list_venue_table_layout':
        final broken = failLayout;
        if (broken != null) throw broken;
        _manager();
        return [
          for (final t in tables)
            {
              'type_id': t['id'],
              'name': t['name'],
              'max_guests': t['max_guests'],
              'inventory_count': t['inventory'],
              'deposit_cents': t['deposit_cents'],
              'floor_id': t['floor_id'],
              'pos_x': t['pos_x'],
              'pos_y': t['pos_y'],
              'width': t['width'],
              'height': t['height'],
              'included_admissions': t['included_admissions'],
            },
        ];
      case 'place_venue_table':
        _manager();
        final x = (p['p_x'] as num?)?.toDouble();
        final y = (p['p_y'] as num?)?.toDouble();
        final w = (p['p_w'] as num?)?.toDouble();
        final h = (p['p_h'] as num?)?.toDouble();
        if (p['p_floor'] == null || x == null || y == null || w == null || h == null) throw refuse('choose a floor and where the table goes');
        if (x < 0 || y < 0 || w < 2 || h < 2 || x + w > 100.01 || y + h > 100.01) throw refuse('the table must be at least 2 percent wide and high and fully inside the floor plan');
        final t = tables.where((e) => e['id'] == p['p_type']).firstOrNull;
        if (t == null) throw refuse('table type not found');
        t['floor_id'] = p['p_floor'];
        t['pos_x'] = double.parse(x.toStringAsFixed(2));
        t['pos_y'] = double.parse(y.toStringAsFixed(2));
        t['width'] = double.parse(w.toStringAsFixed(2));
        t['height'] = double.parse(h.toStringAsFixed(2));
        return null;
      case 'unplace_venue_table':
        _manager();
        final t = tables.where((e) => e['id'] == p['p_type']).firstOrNull;
        if (t == null) throw refuse('table type not found');
        t['floor_id'] = t['pos_x'] = t['pos_y'] = t['width'] = t['height'] = null;
        return null;
      case 'set_table_included_admissions':
        _manager();
        final t = tables.where((e) => e['id'] == p['p_type']).firstOrNull;
        if (t == null) throw refuse('table type not found');
        final n = p['p_count'] as int?;
        if (n != null && (n < 0 || n > 100)) throw refuse('included admissions must be between 0 and 100');
        if (n != null && n > (t['max_guests'] as int)) throw refuse('a booking cannot include more admissions ($n) than the table seats (${t['max_guests']})');
        t['included_admissions'] = n;
        return null;
      case 'venue_deposit_terms':
        _manager();
        return [{'terms': depositTerms, 'deposit_is_credit': depositIsCredit}];
      case 'save_venue_deposit_terms':
        _manager();
        final d = p['p_details'] as Map<String, dynamic>;
        for (final k in d.keys) {
          if (!const {'recipient', 'venue_pct', 'purpose'}.contains(k)) throw refuse('unknown field: $k');
        }
        final recipient = d['recipient'] as String?;
        var pct = d['venue_pct'] as int?;
        final purpose = d['purpose'] as String?;
        if (recipient == null || !const {'venue', 'organizer', 'split'}.contains(recipient)) throw refuse('choose who receives the deposit: the venue, the approved organizer, or a split');
        if (purpose == null || !const {'reservation_fee', 'minimum_spend_credit', 'admission'}.contains(purpose)) {
          throw refuse('choose what the deposit is for: a reservation fee, a credit toward the minimum spend, or admission');
        }
        if (recipient == 'venue') {
          if (pct != null && pct != 100) throw refuse('when the venue keeps the deposit its share is 100 percent');
          pct = 100;
        } else if (recipient == 'organizer') {
          if (pct != null && pct != 0) throw refuse('when the organizer receives the deposit the venue\'s share is 0 percent');
          pct = 0;
        } else if (pct == null || pct < 1 || pct > 99) {
          throw refuse('for a split give the venue\'s share between 1 and 99 percent (the organizer gets the rest, so the two add up to 100)');
        }
        if (purpose == 'minimum_spend_credit' && !depositIsCredit) {
          throw refuse('the deposit is not credited toward the bottle bill at this venue, so it cannot be a minimum spend credit; choose reservation fee or admission, or ask the BottlesUp team to switch the credit on');
        }
        if (purpose != 'minimum_spend_credit' && depositIsCredit) {
          throw refuse('the deposit is credited toward the bottle bill at this venue, so its purpose is a minimum spend credit; ask the BottlesUp team if that should change');
        }
        depositTerms = {'recipient': recipient, 'venue_pct': pct, 'purpose': purpose};
        return depositTerms;
    }
    throw StateError('unexpected call $function');
  }

  void _manager() {
    if (role != 'manager') throw refuse('not allowed');
  }

  Map<String, dynamic> _booking(Object? bookingId) {
    final b = bookings.where((x) => x['id'] == bookingId).firstOrNull;
    if (b == null) throw refuse('not allowed');
    return b;
  }
}
