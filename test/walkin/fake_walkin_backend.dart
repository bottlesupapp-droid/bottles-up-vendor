import 'package:bottles_up_vendor/features/walkin/services/walkin_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

PostgrestException refuse(String message) => PostgrestException(message: message, code: 'P0001');

/// The website's walk-in functions (20261020140000_desk_walkin.sql) as a fake with the same checks, in the same order, and the same sentences: only a manager,
/// the terms confirmed, a name and an e-mail address, a party that fits the table, hours for an hourly table, the same guest not booked twice for the same
/// time, and a table of that type still left (counted from the bookings, so a table taken in the meantime is gone). Ids: slots s1.., tables t1..
class FakeWalkinBackend {
  String role = 'manager';

  /// Arrival times: id, start_time, label.
  final List<Map<String, dynamic>> slots = [
    {'id': 's1', 'start_time': '21:00:00', 'label': null},
    {'id': 's2', 'start_time': '23:00:00', 'label': 'Late'},
  ];

  /// Table types: id, name, max_guests, min_guests, pricing_mode, deposit_cents, hourly_rate_cents, min_hours, inventory.
  final List<Map<String, dynamic>> tables = [
    {'id': 't1', 'name': 'Booth 3', 'max_guests': 6, 'min_guests': 2, 'pricing_mode': 'flat', 'deposit_cents': 10000, 'hourly_rate_cents': null, 'min_hours': null, 'inventory': 2},
    {'id': 't2', 'name': 'Lounge', 'max_guests': 10, 'min_guests': null, 'pricing_mode': 'hourly', 'deposit_cents': 0, 'hourly_rate_cents': 5000, 'min_hours': 2, 'inventory': 1},
  ];

  /// Bookings already made: table, slot, email.
  final List<Map<String, String>> booked = [];
  final List<(String, Map<String, dynamic>?)> calls = [];
  int _next = 0;

  Object? failAll;
  Object? failOptions;
  Object? failCreate;
  void Function(String function)? beforeCall;
  Future<void>? hold;

  WalkinService get service => WalkinService(caller: call);

  List<Map<String, dynamic>> paramsOf(String function) => [for (final c in calls) if (c.$1 == function) c.$2 ?? const {}];

  int count(String table, String slot) => booked.where((b) => b['table'] == table && b['slot'] == slot).length;

  /// Someone else books [table] at [slot] (another phone at the same moment).
  void takeTable(String table, String slot, {String email = 'other@guest.example'}) => booked.add({'table': table, 'slot': slot, 'email': email});

  Future<dynamic> call(String function, {Map<String, dynamic>? params}) async {
    calls.add((function, params));
    final broken = failAll;
    if (broken != null) throw broken;
    beforeCall?.call(function);
    final waiting = hold;
    if (waiting != null) await waiting;
    final p = params ?? const {};
    if (role == 'none') throw refuse('not authenticated');
    if (role != 'manager') throw refuse('not allowed');
    switch (function) {
      case 'desk_walkin_options':
        final broken = failOptions;
        if (broken != null) throw broken;
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
                'min_guests': t['min_guests'],
                'pricing_mode': t['pricing_mode'],
                'deposit_cents': t['deposit_cents'],
                'hourly_rate_cents': t['hourly_rate_cents'],
                'min_hours': t['min_hours'],
                'inventory': t['inventory'],
                'booked': count(t['id'] as String, s['id'] as String),
                'available': ((t['inventory'] as int) - count(t['id'] as String, s['id'] as String)).clamp(0, 1000),
              },
        ];
      case 'desk_create_walkin':
        final broken = failCreate;
        if (broken != null) throw broken;
        if (p['p_terms_confirmed'] != true) throw refuse('confirm that the guest has been told the terms and agrees to them');
        final name = (p['p_name'] as String? ?? '').trim();
        final email = (p['p_email'] as String? ?? '').trim().toLowerCase();
        final phone = p['p_phone'] as String?;
        if (name.length < 2 || name.length > 120) throw refuse('the guest\'s name needs 2 to 120 characters');
        if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email) || email.length > 254) throw refuse('enter a valid email address for the guest');
        if (phone != null && phone.trim().length > 40) throw refuse('the phone number is too long');
        final t = tables.where((x) => x['id'] == p['p_table_type']).firstOrNull;
        if (t == null) throw refuse('table not found');
        final s = slots.where((x) => x['id'] == p['p_slot']).firstOrNull;
        if (s == null) throw refuse('arrival time not found');
        final g = p['p_guests'] as int?;
        if (g == null || g < 1) throw refuse('how many guests?');
        if (g > (t['max_guests'] as int)) throw refuse('this table seats up to ${t['max_guests']} guests');
        if (t['min_guests'] != null && g < (t['min_guests'] as int)) throw refuse('this table needs at least ${t['min_guests']} guests');
        var deposit = t['deposit_cents'] as int;
        if (t['pricing_mode'] == 'hourly') {
          final h = p['p_hours'] as int?;
          final min = (t['min_hours'] as int?) ?? 1;
          if (h == null || h < min || h > 24) throw refuse('this table needs between $min and 24 hours');
          deposit = (t['hourly_rate_cents'] as int) * h;
        }
        if (booked.any((b) => b['table'] == t['id'] && b['slot'] == s['id'] && b['email'] == email)) throw refuse('this guest already has a booking for that time');
        final n = count(t['id'] as String, s['id'] as String);
        if (n >= (t['inventory'] as int)) throw refuse('no tables of this type are left for that time');
        booked.add({'table': t['id'] as String, 'slot': s['id'] as String, 'email': email});
        _next++;
        return {
          'booking_id': 'bk$_next',
          'confirmation_code': 'WALK$_next',
          'deposit_cents': deposit,
          'due_cents': deposit,
          'arrival_date': p['p_night'],
          'tables_left': (t['inventory'] as int) - n - 1,
        };
    }
    throw StateError('unexpected call $function');
  }
}
