import '../../owner/logic/setup_forms.dart' show formatDollars;

// Walk-in table booking (developer brief 15 Oct, section 17). Pure Dart, tested without a screen. Each check mirrors the database function that finally decides
// (website: desk_walkin_options and desk_create_walkin, 20261020140000_desk_walkin.sql), so the form says what is wrong in plain words before anything is sent and
// the database still refuses whatever gets past it. The deposit is DUE at the club after booking: nothing here marks money as collected.

class WalkinTable {
  const WalkinTable({
    required this.id,
    required this.name,
    required this.maxGuests,
    required this.hourly,
    required this.depositCents,
    required this.inventory,
    required this.booked,
    required this.available,
    this.minGuests,
    this.hourlyRateCents,
    this.minHours,
  });

  final String id;
  final String name;
  final int maxGuests;
  final int? minGuests;

  /// Priced by the hour (rate times hours) instead of a flat deposit.
  final bool hourly;
  final int depositCents;
  final int? hourlyRateCents;
  final int? minHours;
  final int inventory;
  final int booked;
  final int available;

  bool get isFree => available > 0;

  /// What the deposit is for [hours] (ignored for a flat table).
  int depositFor(int? hours) => hourly ? (hourlyRateCents ?? 0) * (hours ?? minHours ?? 1) : depositCents;
}

class WalkinSlot {
  const WalkinSlot({required this.id, required this.startTime, required this.tables, this.label});

  final String id;

  /// 'HH:MM:SS' as stored.
  final String startTime;
  final String? label;
  final List<WalkinTable> tables;

  bool get hasFreeTable => tables.any((t) => t.isFree);
}

int? _int(Object? v) => v is num ? v.toInt() : int.tryParse('$v');

/// The rows of desk_walkin_options, grouped by arrival time in the order the database gave them. A row without a table or a time is dropped.
List<WalkinSlot> parseWalkinOptions(List<Map<String, dynamic>> rows) {
  final order = <String>[];
  final meta = <String, ({String start, String? label})>{};
  final tables = <String, List<WalkinTable>>{};
  for (final r in rows) {
    final slot = r['slot_id']?.toString();
    final table = r['table_type_id']?.toString();
    final start = r['start_time']?.toString();
    final name = r['table_name']?.toString();
    final max = _int(r['max_guests']);
    if (slot == null || table == null || start == null || name == null || max == null) continue;
    if (!tables.containsKey(slot)) {
      order.add(slot);
      final label = r['slot_label']?.toString();
      meta[slot] = (start: start, label: label == null || label.isEmpty ? null : label);
      tables[slot] = [];
    }
    tables[slot]!.add(WalkinTable(
      id: table,
      name: name,
      maxGuests: max,
      minGuests: _int(r['min_guests']),
      hourly: r['pricing_mode'] == 'hourly',
      depositCents: _int(r['deposit_cents']) ?? 0,
      hourlyRateCents: _int(r['hourly_rate_cents']),
      minHours: _int(r['min_hours']),
      inventory: _int(r['inventory']) ?? 0,
      booked: _int(r['booked']) ?? 0,
      available: _int(r['available']) ?? 0,
    ));
  }
  return [for (final id in order) WalkinSlot(id: id, startTime: meta[id]!.start, label: meta[id]!.label, tables: tables[id]!)];
}

/// '21:00:00' -> '9:00 PM', '01:00:00' -> '1:00 AM'.
String slotTime(String start) {
  final m = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(start);
  if (m == null) return start;
  final h = int.parse(m.group(1)!);
  return '${h % 12 == 0 ? 12 : h % 12}:${m.group(2)} ${h < 12 ? 'AM' : 'PM'}';
}

String slotLabel(WalkinSlot s) => s.label == null ? slotTime(s.startTime) : '${slotTime(s.startTime)} · ${s.label}';

/// "4 seats · $100.00 deposit · 1 left".
String tableLine(WalkinTable t) {
  final price = t.hourly ? '${formatDollars(t.hourlyRateCents ?? 0)} an hour${t.minHours != null && t.minHours! > 1 ? ' (at least ${t.minHours} hours)' : ''}' : (t.depositCents > 0 ? '${formatDollars(t.depositCents)} deposit' : 'no deposit');
  final seats = t.minGuests != null ? '${t.minGuests} to ${t.maxGuests} guests' : 'up to ${t.maxGuests} guests';
  final left = t.isFree ? '${t.available} left' : 'fully booked';
  return '$seats · $price · $left';
}

class WalkinForm {
  const WalkinForm({
    required this.name,
    required this.email,
    this.phone = '',
    required this.guests,
    this.hours,
    required this.terms,
  });

  final String name;
  final String email;
  final String phone;
  final int? guests;
  final int? hours;
  final bool terms;
}

final RegExp _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

/// What is wrong with the form, in plain words, in the order the form reads. Empty means it can be sent.
List<String> validateWalkin(WalkinForm f, WalkinTable table) {
  final out = <String>[];
  final name = f.name.trim();
  if (name.length < 2 || name.length > 120) out.add('Enter the guest\'s name (2 to 120 characters).');
  final email = f.email.trim();
  if (!_email.hasMatch(email) || email.length > 254) out.add('Enter a valid email address for the guest.');
  if (f.phone.trim().length > 40) out.add('The phone number is too long.');
  final g = f.guests;
  if (g == null || g < 1) {
    out.add('How many guests?');
  } else if (g > table.maxGuests) {
    out.add('This table seats up to ${table.maxGuests} guests.');
  } else if (table.minGuests != null && g < table.minGuests!) {
    out.add('This table needs at least ${table.minGuests} guests.');
  }
  if (table.hourly) {
    final min = table.minHours ?? 1;
    final h = f.hours;
    if (h == null || h < min || h > 24) out.add('This table needs between $min and 24 hours.');
  }
  if (!f.terms) out.add('Confirm that the guest has been told the terms and agrees to them.');
  return out;
}

/// The terms the guest is agreeing to, in words.
List<String> walkinTerms(WalkinTable table, int? hours) {
  final deposit = table.depositFor(hours);
  return [
    deposit > 0 ? 'The deposit of ${formatDollars(deposit)} is paid at the club. It is recorded as paid only when you record the payment.' : 'There is no deposit for this table.',
    if (table.hourly) 'This table is booked by the hour: ${hours ?? table.minHours ?? 1} hours.',
    'Bottles are ordered for the table afterwards and paid for at the club.',
    'The booking is confirmed now and the table is taken from the club\'s availability.',
  ];
}

class WalkinResult {
  const WalkinResult({required this.bookingId, required this.code, required this.depositCents, required this.dueCents, required this.arrivalDate, required this.tablesLeft});

  final String bookingId;
  final String code;
  final int depositCents;
  final int dueCents;
  final String arrivalDate;
  final int tablesLeft;
}

WalkinResult? parseWalkinResult(Map<String, dynamic> row) {
  final id = row['booking_id']?.toString();
  final code = row['confirmation_code']?.toString();
  if (id == null || id.isEmpty || code == null || code.isEmpty) return null;
  return WalkinResult(
    bookingId: id,
    code: code,
    depositCents: _int(row['deposit_cents']) ?? 0,
    dueCents: _int(row['due_cents']) ?? 0,
    arrivalDate: row['arrival_date']?.toString() ?? '',
    tablesLeft: _int(row['tables_left']) ?? 0,
  );
}

/// The database says what is left was taken in the meantime: the options must be read again.
bool isSoldOutRefusal(String message) => message.toLowerCase().contains('no tables of this type are left');
