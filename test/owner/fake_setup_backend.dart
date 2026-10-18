import 'dart:typed_data';

import 'package:bottles_up_vendor/features/owner/services/media_service.dart';
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
  final List<Map<String, dynamic>> floors = [];

  /// The venue's row as `site_venues` would give it (name, description, address, cover_image_url), or null when nobody may read it.
  Map<String, dynamic>? profileRow = {'id': 'v1', 'name': 'Club Noir', 'description': 'A dark club', 'address': '12 King St W', 'cover_image_url': 'https://img.example/cover.jpg'};
  Object? failAll;

  /// The venue's payment settings as the database holds them (site_venues.bottle_payment_mode and deposit_is_credit).
  String bottleMode = 'pay_ahead';
  bool depositIsCredit = false;

  /// The database answers the payment read with no row at all (the venue is gone, or the person lost access).
  bool noPaymentRow = false;

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

  VenueSetupService get service => VenueSetupService(rpc: call, profileLoader: (venueId) async {
        calls.add(('read_profile', {'p_venue': venueId}));
        final broken = failAll;
        if (broken != null) throw broken;
        return profileRow == null ? null : Map<String, dynamic>.from(profileRow!);
      });

  Future<dynamic> call(String function, {Map<String, dynamic>? params}) async {
    calls.add((function, params));
    final broken = failAll;
    if (broken != null) throw broken;
    beforeCall?.call(function);
    final waiting = hold;
    if (waiting != null) await waiting;
    final p = params ?? const {};
    switch (function) {
      case 'venue_payment_rules':
        return noPaymentRow ? <Map<String, dynamic>>[] : [{'bottle_payment_mode': bottleMode, 'deposit_is_credit': depositIsCredit}];
      case 'save_venue_payment_rules':
        final details = p['p_details'] as Map<String, dynamic>;
        if (details.containsKey('deposit_is_credit')) {
          throw refuse('whether the deposit is credited against the bottle bill cannot be changed here, because bookings that already exist are worked out with it; ask the BottlesUp team');
        }
        for (final k in details.keys) {
          if (k != 'bottle_payment_mode') throw refuse('unknown field: $k');
        }
        final mode = (details['bottle_payment_mode'] as String?)?.trim();
        if (mode == null) throw refuse('choose how bottles are paid');
        if (!const {'pay_ahead', 'pay_at_club', 'both'}.contains(mode)) throw refuse('bottle payment must be pay ahead, pay at the venue, or the customer chooses');
        bottleMode = mode;
        return mode;
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
      case 'list_venue_floors':
        return [for (final f in floors) Map<String, dynamic>.from(f)];
      case 'save_venue_floor':
        final label = (p['p_label'] as String?)?.trim() ?? '';
        final image = (p['p_image_url'] as String?)?.trim() ?? '';
        if (label.isEmpty) throw refuse('a floor name is required');
        if (label.length > 60) throw refuse('floor name must be 60 characters or fewer');
        if (image.isEmpty) throw refuse('a floor plan image is required');
        if (!image.startsWith('https://')) throw refuse('floor plan image must be an https link');
        final id = p['p_floor'] as String?;
        if (id == null) {
          if (floors.length >= 10) throw refuse('a venue can have 10 floors at most');
          final row = {'floor_id': this.id('f'), 'label': label, 'image_url': image, 'sort_order': floors.length, 'table_count': 0};
          floors.add(row);
          return row['floor_id'];
        }
        final i = floors.indexWhere((f) => f['floor_id'] == id);
        if (i < 0) throw refuse('floor not found');
        floors[i] = {...floors[i], 'label': label, 'image_url': image};
        return id;
      case 'remove_venue_floor':
        final i = floors.indexWhere((f) => f['floor_id'] == p['p_floor']);
        if (i < 0) throw refuse('floor not found');
        floors.removeAt(i);
        return null;
      case 'update_venue_profile':
        final d = p['p_details'] as Map<String, dynamic>;
        for (final k in d.keys) {
          if (!{'name', 'description', 'address', 'cover_image_url', 'gallery'}.contains(k)) throw refuse('unknown field: $k');
        }
        if (d.containsKey('name') && (((d['name'] as String?)?.trim().isEmpty ?? true) || (d['name'] as String).length > 120)) throw refuse('name is required (120 characters at most)');
        if (d.containsKey('description') && (d['description'] as String? ?? '').length > 4000) throw refuse('description must be 4000 characters or fewer');
        if (d.containsKey('address') && (d['address'] as String? ?? '').length > 300) throw refuse('address is too long');
        if (d.containsKey('cover_image_url') && d['cover_image_url'] != null && !(d['cover_image_url'] as String).startsWith('https://')) throw refuse('cover image must be an https link');
        profileRow = {...?profileRow, ...d};
        return p['p_venue'];
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

Map<String, dynamic> floorRowJson(String id, String label, {String image = 'https://img.example/main.jpg', int tables = 0, int order = 0}) =>
    {'floor_id': id, 'label': label, 'image_url': image, 'sort_order': order, 'table_count': tables};

/// A stand-in for the photo storage: records what was uploaded, can be told to refuse, and answers the public address a real bucket would.
class FakeMedia {
  final List<(String path, int size, String contentType)> uploads = [];
  bool refuse = false;
  Future<void>? hold;
  int _n = 0;

  MediaService get service => MediaService(
        newId: () => 'img${++_n}',
        uploader: (path, bytes, contentType) async {
          final waiting = hold;
          if (waiting != null) await waiting;
          if (refuse) throw Exception('new row violates row-level security policy');
          uploads.add((path, bytes.length, contentType));
          return 'https://img.example/$path';
        },
      );
}

Uint8List jpegBytes([int length = 64]) => Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, ...List.filled(length - 4, 7)]);
Uint8List pngBytes() => Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 1, 2, 3, 4]);
Uint8List gifBytes() => Uint8List.fromList([0x47, 0x49, 0x46, 0x38, 0x39, 0x61, 1, 2, 3]);
