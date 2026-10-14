import 'package:bottles_up_vendor/features/owner/services/venue_setup_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A stand-in for the website's `list_/add_/save_/remove_venue_*` functions that behaves the way they do: it keeps rows,
/// refuses a field it does not know, merges only the fields it is sent, and refuses what the database refuses, with the
/// database's own sentences (raised as P0001, like `raise exception`).
class FakeSetupBackend {
  final List<(String, Map<String, dynamic>?)> calls = [];
  final List<Map<String, dynamic>> slots = [];
  final List<Map<String, dynamic>> tables = [];
  final List<Map<String, dynamic>> bottles = [];
  Object? failAll;

  /// Runs before each call; a test throws from it to fail only the call it chooses.
  void Function(String function)? beforeCall;

  /// When set, every call waits for it before answering (to test what a second tap does while the first is still going).
  Future<void>? hold;
  int _next = 1;

  static const tableKeys = {
    'name', 'description', 'max_guests', 'min_guests', 'min_spend_cents', 'deposit_cents', 'inventory_count', 'image_url',
    'badge_label', 'is_featured', 'pricing_mode', 'hourly_rate_cents', 'min_hours', 'sort_order',
  };
  static const bottleKeys = {
    'name', 'size', 'description', 'price_cents', 'category', 'image_url', 'is_available', 'is_sold_out', 'stock_quantity', 'sort_order',
  };

  PostgrestException refuse(String message) => PostgrestException(message: message, code: 'P0001');

  String id(String prefix) => '$prefix${_next++}';

  VenueSetupService get service => VenueSetupService(rpc: call);

  Future<dynamic> call(String function, {Map<String, dynamic>? params}) async {
    calls.add((function, params));
    final broken = failAll;
    if (broken != null) throw broken;
    beforeCall?.call(function);
    final waiting = hold;
    if (waiting != null) await waiting;
    final p = params ?? const {};
    switch (function) {
      case 'list_venue_time_slots':
        return [for (final s in slots) Map<String, dynamic>.from(s)];
      case 'add_venue_time_slot':
        final day = p['p_day'] as int;
        final start = _clock(p['p_start'] as String);
        if (slots.any((s) => s['day_of_week'] == day && s['start_time'] == start)) throw refuse('that arrival time is already added');
        final slot = {'slot_id': id('s'), 'day_of_week': day, 'start_time': start, 'label': p['p_label'], 'booking_count': 0};
        slots.add(slot);
        return slot['slot_id'];
      case 'remove_venue_time_slot':
        final i = slots.indexWhere((s) => s['slot_id'] == p['p_slot']);
        if (i < 0) throw refuse('arrival time not found');
        if ((slots[i]['booking_count'] as int) > 0) throw refuse('this arrival time has bookings, so it cannot be removed');
        slots.removeAt(i);
        return null;
      case 'list_venue_table_types':
        return [for (final t in tables) Map<String, dynamic>.from(t)];
      case 'save_venue_table_type':
        return _save(tables, 'type_id', p['p_type'] as String?, p['p_details'] as Map<String, dynamic>, tableKeys, 't', {
          'description': null, 'min_guests': null, 'image_url': null, 'badge_label': null, 'is_featured': false, 'pricing_mode': 'flat',
          'hourly_rate_cents': null, 'min_hours': null, 'floor_id': null, 'booking_count': 0,
        });
      case 'remove_venue_table_type':
        final i = tables.indexWhere((t) => t['type_id'] == p['p_type']);
        if (i < 0) throw refuse('table type not found');
        if ((tables[i]['booking_count'] as int) > 0) throw refuse('this table type has bookings, so it cannot be removed. Lower the number of tables or rename it instead');
        tables.removeAt(i);
        return null;
      case 'list_venue_bottles':
        return [for (final b in bottles) Map<String, dynamic>.from(b)];
      case 'save_venue_bottle':
        return _save(bottles, 'bottle_id', p['p_bottle'] as String?, p['p_details'] as Map<String, dynamic>, bottleKeys, 'b', {
          'size': null, 'description': null, 'category': null, 'image_url': null, 'is_available': true, 'is_sold_out': false, 'stock_quantity': null,
        });
      case 'remove_venue_bottle':
        final i = bottles.indexWhere((b) => b['bottle_id'] == p['p_bottle']);
        if (i < 0) throw refuse('bottle not found');
        bottles.removeAt(i);
        return null;
    }
    throw StateError('no handler for $function');
  }

  /// "21:00" arrives as the database's time type and comes back as "21:00:00".
  String _clock(String t) => t.length == 5 ? '$t:00' : t;

  String _save(List<Map<String, dynamic>> rows, String idKey, String? rowId, Map<String, dynamic> details, Set<String> allowed, String prefix, Map<String, dynamic> defaults) {
    for (final k in details.keys) {
      if (!allowed.contains(k)) throw refuse('unknown field: $k');
    }
    if (rowId == null) {
      final row = <String, dynamic>{idKey: id(prefix), ...defaults, ...details};
      rows.add(row);
      return row[idKey] as String;
    }
    final i = rows.indexWhere((r) => r[idKey] == rowId);
    if (i < 0) throw refuse(prefix == 't' ? 'table type not found' : 'bottle not found');
    rows[i] = {...rows[i], ...details};
    return rowId;
  }

  int count(String fn) => calls.where((c) => c.$1 == fn).length;
  List<Map<String, dynamic>?> paramsOf(String fn) => [for (final c in calls) if (c.$1 == fn) c.$2];
}

Map<String, dynamic> slotRow(String id, int day, String time, {String? label, int bookings = 0}) =>
    {'slot_id': id, 'day_of_week': day, 'start_time': time, 'label': label, 'booking_count': bookings};

Map<String, dynamic> tableRowJson(String id, String name, {int max = 6, int count = 3, int spend = 150000, int deposit = 50000, int bookings = 0, bool featured = false, String? badge}) => {
      'type_id': id, 'name': name, 'description': null, 'max_guests': max, 'min_guests': null, 'min_spend_cents': spend, 'deposit_cents': deposit,
      'inventory_count': count, 'image_url': 'https://img.example/$id.jpg', 'badge_label': badge, 'is_featured': featured, 'pricing_mode': 'flat',
      'hourly_rate_cents': null, 'min_hours': null, 'floor_id': null, 'booking_count': bookings,
    };

Map<String, dynamic> bottleRowJson(String id, String name, {int price = 19500, bool available = true, bool soldOut = false, int? stock, String? size = '750ml', String? category}) => {
      'bottle_id': id, 'name': name, 'size': size, 'description': null, 'price_cents': price, 'category': category, 'image_url': 'https://img.example/$id.jpg',
      'is_available': available, 'is_sold_out': soldOut, 'stock_quantity': stock,
    };
