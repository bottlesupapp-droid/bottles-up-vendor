import '../../owner/logic/setup_forms.dart' show formatDollars;
import '../../walkin/logic/walkin_rules.dart' show slotTime;

// The floor map, table states, moving a booking and deposit terms (developer brief 15 Oct 2026, sections 13 and 15; the client's answer "similar to the website").
// Pure Dart, tested without a screen. Every check mirrors the database function that finally decides (website repo, 20261021100000_floor_plan_and_table_states.sql),
// so the form says what is wrong in plain words before anything is sent and the database still refuses whatever gets past it.

int? _int(Object? v) => v is num ? v.toInt() : int.tryParse('$v');
double? _num(Object? v) => v is num ? v.toDouble() : double.tryParse('$v');
String? _text(Object? v) {
  final s = v?.toString().trim();
  return s == null || s.isEmpty ? null : s;
}

// ---------------------------------------------------------------------------
// Where a table sits on the floor plan
// ---------------------------------------------------------------------------

/// A box on a floor image, as percentages (0 to 100) of the image: the same columns the website's editor writes, so a table placed in the app shows in the right
/// place on the website's picker at any size.
class PlacedBox {
  const PlacedBox({required this.x, required this.y, required this.w, required this.h});

  final double x;
  final double y;
  final double w;
  final double h;

  @override
  bool operator ==(Object other) => other is PlacedBox && other.x == x && other.y == y && other.w == w && other.h == h;

  @override
  int get hashCode => Object.hash(x, y, w, h);

  @override
  String toString() => 'PlacedBox($x, $y, $w, $h)';
}

/// The smallest a table box may be, in percent of the floor image (the database refuses less).
const double minBoxPercent = 2;

double _round2(double v) => (v * 100).round() / 100;

/// The box brought inside the floor image and no smaller than the minimum, rounded to two decimals like the database stores it.
PlacedBox clampBox(PlacedBox b) {
  final w = _round2(b.w.clamp(minBoxPercent, 100.0));
  final h = _round2(b.h.clamp(minBoxPercent, 100.0));
  final x = _round2(b.x.clamp(0.0, 100.0 - w));
  final y = _round2(b.y.clamp(0.0, 100.0 - h));
  return PlacedBox(x: x, y: y, w: w, h: h);
}

PlacedBox moveBox(PlacedBox b, double dx, double dy) => clampBox(PlacedBox(x: b.x + dx, y: b.y + dy, w: b.w, h: b.h));

/// Resizing keeps the top-left corner where it is; the box grows only as far as the picture goes.
PlacedBox resizeBox(PlacedBox b, double dw, double dh) => clampBox(PlacedBox(
      x: b.x,
      y: b.y,
      w: (b.w + dw).clamp(minBoxPercent, _atLeastMin(100.0 - b.x)),
      h: (b.h + dh).clamp(minBoxPercent, _atLeastMin(100.0 - b.y)),
    ));

double _atLeastMin(double room) => room < minBoxPercent ? minBoxPercent : room;

/// Where a table that has just been put on the floor goes: a staggered row so several new ones do not land on top of each other.
PlacedBox defaultBox(int index) {
  final col = index % 5;
  final row = (index ~/ 5) % 5;
  return clampBox(PlacedBox(x: 6 + col * 17, y: 8 + row * 16, w: 12, h: 10));
}

/// A table type with where it is placed and how many guests a booking of it includes.
class TableLayout {
  const TableLayout({
    required this.typeId,
    required this.name,
    required this.maxGuests,
    required this.inventory,
    required this.depositCents,
    this.floorId,
    this.box,
    this.includedAdmissions,
  });

  final String typeId;
  final String name;
  final int maxGuests;
  final int inventory;
  final int depositCents;

  /// Null when the table is not on any floor plan.
  final String? floorId;
  final PlacedBox? box;

  /// How many guests a booking of this table includes; null = not stated.
  final int? includedAdmissions;

  bool get placed => floorId != null && box != null;
}

TableLayout? parseLayout(Map<String, dynamic> r) {
  final id = _text(r['type_id']);
  final name = _text(r['name']);
  final max = _int(r['max_guests']);
  if (id == null || name == null || max == null) return null;
  final floor = _text(r['floor_id']);
  final x = _num(r['pos_x']);
  final y = _num(r['pos_y']);
  final w = _num(r['width']);
  final h = _num(r['height']);
  final box = floor != null && x != null && y != null && w != null && h != null ? PlacedBox(x: x, y: y, w: w, h: h) : null;
  return TableLayout(
    typeId: id,
    name: name,
    maxGuests: max,
    inventory: _int(r['inventory_count']) ?? 0,
    depositCents: _int(r['deposit_cents']) ?? 0,
    floorId: box == null ? null : floor,
    box: box,
    includedAdmissions: _int(r['included_admissions']),
  );
}

enum PlacementAction { place, unplace }

class PlacementChange {
  const PlacementChange({required this.typeId, required this.name, required this.action, this.box});

  final String typeId;
  final String name;
  final PlacementAction action;
  final PlacedBox? box;
}

/// What has to be saved after editing floor [floorId]. [edited] holds the tables the person touched: a box = where the table should be on this floor, null = it should
/// not be on this floor. A table that was not touched, or whose box is where it already was, needs nothing. A table that sits on ANOTHER floor is only changed when it is
/// given a box here; taking it "off" this floor leaves it where it is.
List<PlacementChange> placementChanges({required String floorId, required List<TableLayout> layout, required Map<String, PlacedBox?> edited}) {
  final out = <PlacementChange>[];
  for (final t in layout) {
    if (!edited.containsKey(t.typeId)) continue;
    final want = edited[t.typeId];
    final here = t.placed && t.floorId == floorId;
    if (want != null) {
      if (here && t.box == want) continue;
      out.add(PlacementChange(typeId: t.typeId, name: t.name, action: PlacementAction.place, box: want));
    } else if (here) {
      out.add(PlacementChange(typeId: t.typeId, name: t.name, action: PlacementAction.unplace));
    }
  }
  return out;
}

/// "Booth is on the Terrace floor", "Booth is not on a floor plan".
String placementStatus(TableLayout t, String Function(String floorId) floorName, String thisFloorId) {
  if (!t.placed) return 'Not on a floor plan';
  if (t.floorId == thisFloorId) return 'On this floor';
  return 'On ${floorName(t.floorId!)}';
}

/// The words for what a booking of a table includes.
String admissionsLine(int? included) {
  if (included == null) return 'Admissions included: not stated';
  if (included == 0) return 'Admissions included: none (the booking is not admission)';
  return 'Admissions included: $included ${included == 1 ? 'guest' : 'guests'}';
}

/// What is wrong with the included admissions typed for a table that seats [maxGuests]; null when it can be sent. Empty text means "not stated".
String? validateIncludedAdmissions(String text, int maxGuests) {
  final t = text.trim();
  if (t.isEmpty) return null;
  final n = int.tryParse(t);
  if (n == null || t.contains(RegExp(r'[^0-9]'))) return 'Enter a whole number of guests, or leave it empty if it is not stated.';
  if (n < 0 || n > 100) return 'Included admissions must be between 0 and 100.';
  if (n > maxGuests) return 'A booking cannot include more admissions ($n) than the table seats ($maxGuests).';
  return null;
}

/// The value sent: null for "not stated".
int? includedAdmissionsValue(String text) => text.trim().isEmpty ? null : int.tryParse(text.trim());

// ---------------------------------------------------------------------------
// The floor map: states
// ---------------------------------------------------------------------------

/// One table type at one arrival time, with how many of its tables are in each state.
class TableState {
  const TableState({
    required this.slotId,
    required this.startTime,
    this.slotLabel,
    required this.tableTypeId,
    required this.tableName,
    required this.maxGuests,
    this.floorId,
    this.box,
    required this.inventory,
    required this.booked,
    required this.occupied,
    required this.held,
    required this.unavailable,
    required this.available,
  });

  final String slotId;
  final String startTime;
  final String? slotLabel;
  final String tableTypeId;
  final String tableName;
  final int maxGuests;
  final String? floorId;
  final PlacedBox? box;
  final int inventory;
  final int booked;
  final int occupied;
  final int held;
  final int unavailable;
  final int available;

  bool get placed => floorId != null && box != null;
}

/// What a box on the map shows. A table type with several tables is one box; it shows the state that needs the most attention, and the counts say the rest.
enum MapKind {
  available('Available'),
  held('Held'),
  booked('Booked'),
  occupied('Occupied'),
  unavailable('Unavailable');

  const MapKind(this.label);

  final String label;
}

/// The state a box is drawn in: Available whenever any table is free, otherwise the largest group (ties go to the one that needs more attention: Occupied, then Booked, Held, Unavailable).
MapKind kindOf(TableState s) {
  if (s.available > 0) return MapKind.available;
  final order = [
    (MapKind.occupied, s.occupied),
    (MapKind.booked, s.booked),
    (MapKind.held, s.held),
    (MapKind.unavailable, s.unavailable),
  ];
  var best = order.first;
  for (final o in order.skip(1)) {
    if (o.$2 > best.$2) best = o;
  }
  return best.$2 == 0 ? MapKind.unavailable : best.$1;
}

/// "2 available · 1 booked · 1 held". Nothing that is zero is listed.
String countsLine(TableState s) {
  final parts = <String>[
    if (s.available > 0) '${s.available} available',
    if (s.booked > 0) '${s.booked} booked',
    if (s.occupied > 0) '${s.occupied} occupied',
    if (s.held > 0) '${s.held} held',
    if (s.unavailable > 0) '${s.unavailable} unavailable',
  ];
  return parts.isEmpty ? 'No tables of this kind' : parts.join(' · ');
}

/// One arrival time with the table types and their states.
class MapSlot {
  const MapSlot({required this.id, required this.startTime, this.label, required this.tables});

  final String id;
  final String startTime;
  final String? label;
  final List<TableState> tables;

  String get title => label == null ? slotTime(startTime) : '${slotTime(startTime)} · $label';
}

/// The rows of desk_table_states grouped by arrival time in the order the database gave them. A row without a table or a time is dropped.
List<MapSlot> parseTableStates(List<Map<String, dynamic>> rows) {
  final order = <String>[];
  final meta = <String, ({String start, String? label})>{};
  final tables = <String, List<TableState>>{};
  for (final r in rows) {
    final slot = _text(r['slot_id']);
    final start = _text(r['start_time']);
    final type = _text(r['table_type_id']);
    final name = _text(r['table_name']);
    final max = _int(r['max_guests']);
    if (slot == null || start == null || type == null || name == null || max == null) continue;
    if (!tables.containsKey(slot)) {
      order.add(slot);
      meta[slot] = (start: start, label: _text(r['slot_label']));
      tables[slot] = [];
    }
    final floor = _text(r['floor_id']);
    final x = _num(r['pos_x']);
    final y = _num(r['pos_y']);
    final w = _num(r['width']);
    final h = _num(r['height']);
    final box = floor != null && x != null && y != null && w != null && h != null ? PlacedBox(x: x, y: y, w: w, h: h) : null;
    tables[slot]!.add(TableState(
      slotId: slot,
      startTime: start,
      slotLabel: meta[slot]!.label,
      tableTypeId: type,
      tableName: name,
      maxGuests: max,
      floorId: box == null ? null : floor,
      box: box,
      inventory: _int(r['inventory']) ?? 0,
      booked: _int(r['booked']) ?? 0,
      occupied: _int(r['occupied']) ?? 0,
      held: _int(r['held']) ?? 0,
      unavailable: _int(r['unavailable']) ?? 0,
      available: _int(r['available']) ?? 0,
    ));
  }
  return [for (final id in order) MapSlot(id: id, startTime: meta[id]!.start, label: meta[id]!.label, tables: tables[id]!)];
}

// ---------------------------------------------------------------------------
// Holds and unavailable tables
// ---------------------------------------------------------------------------

/// A manager's hold or an unavailable table, in force.
class TableBlock {
  const TableBlock({
    required this.id,
    required this.tableTypeId,
    required this.tableName,
    required this.slotId,
    required this.startTime,
    required this.kind,
    required this.quantity,
    required this.reason,
    required this.madeBy,
    this.expiresAt,
  });

  final String id;
  final String tableTypeId;
  final String tableName;
  final String slotId;
  final String startTime;

  /// 'held' (for a while) or 'unavailable' (until reopened).
  final String kind;
  final int quantity;
  final String reason;
  final String madeBy;
  final DateTime? expiresAt;

  bool get isHold => kind == 'held';
}

TableBlock? parseBlock(Map<String, dynamic> r) {
  final id = _text(r['block_id']);
  final type = _text(r['table_type_id']);
  final name = _text(r['table_name']);
  final slot = _text(r['slot_id']);
  final start = _text(r['start_time']);
  final kind = _text(r['kind']);
  final qty = _int(r['quantity']);
  if (id == null || type == null || name == null || slot == null || start == null || qty == null) return null;
  if (kind != 'held' && kind != 'unavailable') return null;
  final expires = _text(r['expires_at']);
  return TableBlock(
    id: id,
    tableTypeId: type,
    tableName: name,
    slotId: slot,
    startTime: start,
    kind: kind!,
    quantity: qty,
    reason: _text(r['reason']) ?? '',
    madeBy: _text(r['made_by']) ?? 'Staff member',
    expiresAt: expires == null ? null : DateTime.tryParse(expires)?.toLocal(),
  );
}

String _clock(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final m = t.minute.toString().padLeft(2, '0');
  return '$h:$m ${t.hour < 12 ? 'AM' : 'PM'}';
}

/// "Held: 2 × Booth at 9:00 PM until 10:30 PM" or "Unavailable: 1 × Sofa at 9:00 PM until reopened".
String blockLine(TableBlock b) {
  final what = '${b.quantity} × ${b.tableName} at ${slotTime(b.startTime)}';
  if (b.isHold) {
    final until = b.expiresAt;
    return until == null ? 'Held: $what' : 'Held: $what until ${_clock(until)}';
  }
  return 'Unavailable: $what until reopened';
}

/// How long a hold may last: the choices offered (the database accepts 5 minutes to 24 hours).
const List<int> holdMinutesChoices = [15, 30, 60, 120, 240, 720, 1440];

String holdLabel(int minutes) {
  if (minutes < 60) return '$minutes min';
  if (minutes == 1440) return '24 hours';
  final h = minutes ~/ 60;
  return h == 1 ? '1 hour' : '$h hours';
}

class BlockForm {
  const BlockForm({required this.kind, required this.quantity, required this.reason, this.minutes});

  /// 'held' or 'unavailable'.
  final String kind;
  final int? quantity;
  final String reason;
  final int? minutes;
}

/// What is wrong with a hold or an unavailable table, in plain words. Empty means it can be sent. [free] is how many tables are free now.
List<String> validateBlock(BlockForm f, int free) {
  final out = <String>[];
  final reason = f.reason.trim();
  if (reason.length < 3 || reason.length > 200) out.add('Give a reason of 3 to 200 characters.');
  final q = f.quantity;
  if (q == null || q < 1) {
    out.add('How many tables?');
  } else if (q > free) {
    out.add(free <= 0 ? 'No table of this kind is free for that time, so none can be held or taken out of use.' : 'Only $free of these tables ${free == 1 ? 'is' : 'are'} free for that time. Tables that are already booked or held cannot be blocked.');
  }
  if (f.kind == 'held') {
    final m = f.minutes;
    if (m == null || m < 5 || m > 1440) out.add('A hold lasts between 5 minutes and 24 hours.');
  }
  return out;
}

String blockedMessage(BlockForm f, String tableName, int freeAfter) {
  final what = '${f.quantity} × $tableName';
  final base = f.kind == 'held' ? '$what held for ${holdLabel(f.minutes ?? 0)}.' : '$what taken out of use until you reopen ${f.quantity == 1 ? 'it' : 'them'}.';
  return '$base $freeAfter left to sell.';
}

// ---------------------------------------------------------------------------
// Moving a booking
// ---------------------------------------------------------------------------

/// A table a booking could be moved to.
class MoveOption {
  const MoveOption({
    required this.tableTypeId,
    required this.name,
    required this.maxGuests,
    this.minGuests,
    required this.available,
    required this.fits,
    required this.isCurrent,
    this.priceDifferenceCents,
  });

  final String tableTypeId;
  final String name;
  final int maxGuests;
  final int? minGuests;
  final int available;

  /// The party fits the seats and the minimum.
  final bool fits;
  final bool isCurrent;

  /// The new table's flat deposit minus the old one's; null when either table is priced by the hour.
  final int? priceDifferenceCents;

  /// Why the table cannot be chosen, or null when it can.
  String? get whyNot {
    if (isCurrent) return 'Where the booking is now';
    if (!fits) return 'The party does not fit this table (${minGuests != null ? '$minGuests to $maxGuests' : 'up to $maxGuests'} guests)';
    if (available < 1) return 'None free for that time';
    return null;
  }

  bool get canChoose => whyNot == null;
}

MoveOption? parseMoveOption(Map<String, dynamic> r) {
  final id = _text(r['table_type_id']);
  final name = _text(r['table_name']);
  final max = _int(r['max_guests']);
  if (id == null || name == null || max == null) return null;
  return MoveOption(
    tableTypeId: id,
    name: name,
    maxGuests: max,
    minGuests: _int(r['min_guests']),
    available: _int(r['available']) ?? 0,
    fits: r['fits'] == true,
    isCurrent: r['is_current'] == true,
    priceDifferenceCents: _int(r['price_difference_cents']),
  );
}

/// "Costs $75.00 more", "Costs $20.00 less" or "Same price". Null when the price cannot be compared (an hourly table).
String? priceDifferenceLine(int? cents) {
  if (cents == null) return null;
  if (cents == 0) return 'Same deposit';
  return cents > 0 ? 'Deposit ${formatDollars(cents)} more' : 'Deposit ${formatDollars(-cents)} less';
}

/// What is wrong with a move, in plain words. Empty means it can be sent.
List<String> validateMove({required String? toTableTypeId, required String reason}) {
  final out = <String>[];
  if (toTableTypeId == null) out.add('Choose the table to move the booking to.');
  final r = reason.trim();
  if (r.length < 3 || r.length > 200) out.add('Give a reason of 3 to 200 characters.');
  return out;
}

class MoveResult {
  const MoveResult({required this.moveId, required this.from, required this.to, this.priceDifferenceCents});

  final String moveId;
  final String from;
  final String to;
  final int? priceDifferenceCents;
}

MoveResult? parseMoveResult(Map<String, dynamic> r) {
  final id = _text(r['move_id']);
  final from = _text(r['from']);
  final to = _text(r['to']);
  if (id == null || from == null || to == null) return null;
  return MoveResult(moveId: id, from: from, to: to, priceDifferenceCents: _int(r['price_difference_cents']));
}

/// What to tell the manager after a move. The amounts the guest agreed to are not changed by a move; a difference is only recorded.
String moveMessage(MoveResult r) {
  final diff = r.priceDifferenceCents;
  final base = 'Moved from ${r.from} to ${r.to}.';
  if (diff == null || diff == 0) return base;
  return '$base The deposits differ by ${formatDollars(diff.abs())} (${diff > 0 ? 'the new table costs more' : 'the new table costs less'}). The guest\'s amounts were not changed; settle any difference with them at the club.';
}

/// One entry of a booking's move history.
class BookingMove {
  const BookingMove({required this.movedAt, required this.from, required this.to, required this.by, required this.reason, this.priceDifferenceCents});

  final DateTime movedAt;
  final String from;
  final String to;
  final String by;
  final String reason;
  final int? priceDifferenceCents;
}

BookingMove? parseBookingMove(Map<String, dynamic> r) {
  final at = DateTime.tryParse(r['moved_at']?.toString() ?? '');
  final from = _text(r['from_table']);
  final to = _text(r['to_table']);
  if (at == null || from == null || to == null) return null;
  return BookingMove(
    movedAt: at.toLocal(),
    from: from,
    to: to,
    by: _text(r['moved_by']) ?? 'Staff member',
    reason: _text(r['reason']) ?? '',
    priceDifferenceCents: _int(r['price_difference_cents']),
  );
}

// ---------------------------------------------------------------------------
// Deposit terms
// ---------------------------------------------------------------------------

enum DepositRecipient {
  venue('venue', 'The venue', 'The venue keeps the whole deposit.'),
  organizer('organizer', 'The approved organizer', 'The deposit goes to the organizer whose event the booking is for.'),
  split('split', 'Split', 'The deposit is shared between the venue and the organizer.');

  const DepositRecipient(this.db, this.label, this.explanation);

  final String db;
  final String label;
  final String explanation;

  static DepositRecipient? fromDb(String? v) {
    for (final r in values) {
      if (r.db == v) return r;
    }
    return null;
  }
}

enum DepositPurpose {
  reservationFee('reservation_fee', 'Reservation fee', 'Holds the table. It is not counted toward the bottle bill.'),
  minimumSpendCredit('minimum_spend_credit', 'Credit toward the minimum spend', 'Counts toward what the table has to spend on bottles.'),
  admission('admission', 'Admission', 'Pays for the guests\' entry.');

  const DepositPurpose(this.db, this.label, this.explanation);

  final String db;
  final String label;
  final String explanation;

  static DepositPurpose? fromDb(String? v) {
    for (final p in values) {
      if (p.db == v) return p;
    }
    return null;
  }
}

class DepositTerms {
  const DepositTerms({required this.recipient, required this.venuePct, required this.purpose, this.isDefault = false});

  final DepositRecipient recipient;

  /// The venue's share, 0 to 100 (the organizer gets the rest).
  final int venuePct;
  final DepositPurpose purpose;

  /// Not chosen by the venue: what a booking gets when the venue never set any (the venue keeps it).
  final bool isDefault;

  int get organizerPct => 100 - venuePct;
}

DepositTerms? parseDepositTerms(Object? json) {
  if (json is! Map) return null;
  final recipient = DepositRecipient.fromDb(json['recipient']?.toString());
  final purpose = DepositPurpose.fromDb(json['purpose']?.toString());
  final pct = _int(json['venue_pct']);
  if (recipient == null || purpose == null || pct == null || pct < 0 || pct > 100) return null;
  return DepositTerms(recipient: recipient, venuePct: pct, purpose: purpose, isDefault: json['default'] == true);
}

/// The venue's deposit terms. [terms] is null while the venue has not chosen. [depositIsCredit] is the BottlesUp-owned switch that decides which purposes are possible.
class DepositSettings {
  const DepositSettings({this.terms, required this.depositIsCredit});

  final DepositTerms? terms;
  final bool depositIsCredit;
}

DepositSettings? parseDepositSettings(Map<String, dynamic> row) {
  if (!row.containsKey('deposit_is_credit')) return null;
  return DepositSettings(terms: parseDepositTerms(row['terms']), depositIsCredit: row['deposit_is_credit'] == true);
}

/// The purposes the venue may pick: while the deposit is credited toward the bottle bill its purpose is a minimum spend credit, otherwise a reservation fee or admission.
List<DepositPurpose> purposesFor({required bool depositIsCredit}) =>
    depositIsCredit ? const [DepositPurpose.minimumSpendCredit] : const [DepositPurpose.reservationFee, DepositPurpose.admission];

/// The terms in words: "The venue keeps the deposit, as a reservation fee." / "Split: the venue 60%, the organizer 40%, as admission."
String depositTermsLine(DepositTerms t) {
  final who = switch (t.recipient) {
    DepositRecipient.venue => 'The venue keeps the deposit',
    DepositRecipient.organizer => 'The approved organizer receives the deposit',
    DepositRecipient.split => 'The deposit is split: the venue ${t.venuePct}%, the organizer ${t.organizerPct}%',
  };
  final what = switch (t.purpose) {
    DepositPurpose.reservationFee => 'as a reservation fee',
    DepositPurpose.minimumSpendCredit => 'as a credit toward the minimum spend',
    DepositPurpose.admission => 'as admission',
  };
  return '$who, $what.';
}

class DepositTermsForm {
  const DepositTermsForm({this.recipient, this.venuePctText = '', this.purpose});

  final DepositRecipient? recipient;
  final String venuePctText;
  final DepositPurpose? purpose;
}

/// What is wrong with the terms, in plain words. Empty means they can be sent.
List<String> validateDepositTerms(DepositTermsForm f, {required bool depositIsCredit}) {
  final out = <String>[];
  if (f.recipient == null) out.add('Choose who receives the deposit: the venue, the approved organizer, or a split.');
  final p = f.purpose;
  if (p == null) {
    out.add('Choose what the deposit is for.');
  } else if (!purposesFor(depositIsCredit: depositIsCredit).contains(p)) {
    out.add(depositIsCredit
        ? 'The deposit is credited toward the bottle bill at this venue, so its purpose is a credit toward the minimum spend. Ask the BottlesUp team if that should change.'
        : 'The deposit is not credited toward the bottle bill at this venue, so choose a reservation fee or admission. Ask the BottlesUp team if the credit should be switched on.');
  }
  if (f.recipient == DepositRecipient.split) {
    final pct = int.tryParse(f.venuePctText.trim());
    if (pct == null || pct < 1 || pct > 99) out.add('For a split, give the venue\'s share between 1 and 99 percent. The organizer gets the rest.');
  }
  return out;
}

/// The payload of save_venue_deposit_terms: the venue's share is fixed for the two single recipients.
Map<String, dynamic> depositTermsPayload(DepositTermsForm f) => {
      'recipient': f.recipient!.db,
      'venue_pct': switch (f.recipient!) {
        DepositRecipient.venue => 100,
        DepositRecipient.organizer => 0,
        DepositRecipient.split => int.parse(f.venuePctText.trim()),
      },
      'purpose': f.purpose!.db,
    };

DepositTermsForm depositFormFrom(DepositTerms? t) => t == null
    ? const DepositTermsForm()
    : DepositTermsForm(recipient: t.recipient, venuePctText: t.recipient == DepositRecipient.split ? '${t.venuePct}' : '', purpose: t.purpose);

// ---------------------------------------------------------------------------
// The terms a booking was made under
// ---------------------------------------------------------------------------

class BookingTerms {
  const BookingTerms({required this.depositCents, this.deposit, this.includedAdmissions, required this.refundPolicySet, required this.refundPolicyLines});

  final int depositCents;
  final DepositTerms? deposit;
  final int? includedAdmissions;
  final bool refundPolicySet;
  final List<String> refundPolicyLines;
}

BookingTerms? parseBookingTerms(Map<String, dynamic> r) {
  if (!r.containsKey('deposit_cents') && !r.containsKey('refund_policy_set')) return null;
  final lines = r['refund_policy_lines'];
  return BookingTerms(
    depositCents: _int(r['deposit_cents']) ?? 0,
    deposit: parseDepositTerms(r['deposit_terms']),
    includedAdmissions: _int(r['included_admissions']),
    refundPolicySet: r['refund_policy_set'] == true,
    refundPolicyLines: lines is List ? [for (final l in lines) if (l != null && l.toString().trim().isNotEmpty) l.toString()] : const [],
  );
}

/// The card on a booking's page, line by line.
List<String> bookingTermsLines(BookingTerms t) => [
      t.depositCents > 0 ? 'Deposit: ${formatDollars(t.depositCents)}' : 'No deposit',
      if (t.depositCents > 0) (t.deposit == null ? 'Deposit terms were not recorded for this booking.' : depositTermsLine(t.deposit!)),
      admissionsLine(t.includedAdmissions),
      if (t.refundPolicySet) ...t.refundPolicyLines else 'No refund policy was set when this was booked.',
    ];
