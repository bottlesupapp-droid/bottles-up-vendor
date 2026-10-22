import 'dart:math';

import '../../owner/logic/setup_forms.dart' show formatDollars;

// Selling a ticket at the door and the door person's shift summary (developer brief 15 Oct 2026, section 26; the client's answer of 20 Oct: cash, the club's own card machine and online
// tickets, the staff member records the method, the ticket is issued and checked in once, no new card reader). Pure Dart, tested without a screen. BottlesUp takes no payment here: the
// person records HOW the guest paid (cash, or the club's own card machine with that machine's receipt number); the database checks the rest (website repo,
// 20261026100000_door_sales.sql: door_sale_options, door_sell_ticket, door_shift_summary).
//
// Not here, on purpose: an approved discount or a promo code (ticket discounts are not built), a card payment through BottlesUp, and e-mailing the ticket (an e-mail address is only kept with the sale).

int? _int(Object? v) => v is num ? v.toInt() : int.tryParse('$v');
String? _text(Object? v) {
  final s = v?.toString().trim();
  return s == null || s.isEmpty ? null : s;
}

/// The limits the database enforces (the same numbers, checked here first so the person is told before the call, not after it).
const int maxTicketsPerSale = 20;
const int guestNameMin = 2;
const int guestNameMax = 120;
const int receiptMin = 3;
const int receiptMax = 120;
const int phoneMax = 40;
const int emailMax = 254;
const int saleKeyMin = 8;
const int saleKeyMax = 80;

/// The window in which the database lets the door sell (the same as the door's own event list): from this long before the event starts until this long after it ends.
const Duration salesOpenBefore = Duration(hours: 24);
const Duration salesOpenAfter = Duration(hours: 3);

/// What the person sees when the database says selling is not open for the event.
const String salesClosedMessage = 'Ticket sales at the door are not open for this event. They open a day before it starts and close three hours after it ends.';

/// One ticket type the door may sell now.
class SaleOption {
  const SaleOption({required this.tierId, required this.name, required this.priceCents, required this.currency, required this.capacity, required this.soldCount, required this.available});

  final String tierId;
  final String name;
  final int priceCents;
  final String currency;
  final int capacity;
  final int soldCount;

  /// What is left to sell (never below zero).
  final int available;

  bool get isFree => priceCents == 0;
  bool get soldOut => available <= 0;

  /// The most that can be sold in one sale: what is left, and never more than the database allows at once.
  int get maxQuantity => available < 0 ? 0 : (available > maxTicketsPerSale ? maxTicketsPerSale : available);

  String get priceLabel => isFree ? 'Free' : formatDollars(priceCents);
  String get leftLabel => soldOut ? 'Sold out' : '$available left';
}

SaleOption? parseSaleOption(Map<String, dynamic> row) {
  final id = row['tier_id'];
  final name = _text(row['tier_name']);
  final price = _int(row['price_cents']);
  if (id is! String || name == null || price == null) return null;
  final capacity = _int(row['capacity']) ?? 0;
  final sold = _int(row['sold_count']) ?? 0;
  final available = _int(row['available']) ?? (capacity - sold);
  return SaleOption(
    tierId: id,
    name: name,
    priceCents: price,
    currency: _text(row['currency']) ?? 'cad',
    capacity: capacity,
    soldCount: sold,
    available: available < 0 ? 0 : available,
  );
}

/// What the door can sell for an event now, or the answer that selling is not open for it.
class SaleOptions {
  const SaleOptions({required this.closed, required this.options});

  final bool closed;
  final List<SaleOption> options;
}

/// How the guest paid. BottlesUp is not the one taking the money: the person records which of the two it was.
enum DoorPayMethod {
  cash('cash', 'Cash', 'The guest paid in cash.'),
  terminal('external_terminal', 'Card machine', 'The guest paid on the club\'s own card machine. Its receipt number is recorded.');

  const DoorPayMethod(this.db, this.label, this.hint);

  /// The value the database stores.
  final String db;
  final String label;
  final String hint;

  /// A card machine payment is recorded with the machine's own receipt number, so it can be found later.
  bool get needsReference => this == DoorPayMethod.terminal;

  static DoorPayMethod? fromDb(Object? v) {
    for (final m in values) {
      if (m.db == v) return m;
    }
    return null;
  }
}

final RegExp _emailShape = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

/// The first thing wrong with a sale about to be made, as a sentence for the person, or null when it can go ahead. The database checks all of this again and has the last word.
String? validateSale({
  required SaleOption? option,
  required int quantity,
  required DoorPayMethod? method,
  required String name,
  required String email,
  required String phone,
  required String reference,
}) {
  if (option == null) return 'Choose a ticket type.';
  if (option.soldOut) return '${option.name} is sold out.';
  if (quantity < 1 || quantity > option.maxQuantity) {
    return option.maxQuantity == 1 ? 'Only 1 ticket can be sold.' : 'Choose between 1 and ${option.maxQuantity} tickets.';
  }
  final n = name.trim();
  if (n.length < guestNameMin) return 'Enter the guest\'s name (at least $guestNameMin letters).';
  if (n.length > guestNameMax) return 'The guest\'s name is too long.';
  final e = email.trim();
  if (e.isNotEmpty && (e.length > emailMax || !_emailShape.hasMatch(e))) return 'That email address does not look right. Fix it, or leave it empty.';
  if (phone.trim().length > phoneMax) return 'That phone number is too long.';
  if (method == null) return 'Choose how the guest paid: cash, or the card machine.';
  final r = reference.trim();
  if (method.needsReference && r.isEmpty) return 'Enter the card machine\'s receipt number.';
  if (r.isNotEmpty && (r.length < receiptMin || r.length > receiptMax)) return 'The receipt number needs $receiptMin to $receiptMax characters.';
  return null;
}

/// What the sale comes to, in cents.
int saleTotalCents(SaleOption option, int quantity) => option.priceCents * quantity;

/// "2 × General · $100.00 · Cash": the line the person confirms.
String saleSummaryLine(SaleOption option, int quantity, DoorPayMethod method) {
  final total = saleTotalCents(option, quantity);
  return '$quantity × ${option.name} · ${total == 0 ? 'Free' : formatDollars(total)} · ${method.label}';
}

/// A new key for one sale attempt. The database treats the same key from the same person as the same sale, so a retry or a second tap can never sell twice.
String newSaleKey({Random? random, DateTime? now}) {
  final r = random ?? Random.secure();
  final t = (now ?? DateTime.now()).microsecondsSinceEpoch.toRadixString(36);
  final salt = List.generate(8, (_) => r.nextInt(36).toRadixString(36)).join();
  return 'ds-$t-$salt';
}

/// What a sale is, for deciding whether the same key may be used again: any change to the sale is a different sale and gets its own key.
String saleFingerprint({
  required String eventId,
  required String tierId,
  required int quantity,
  required DoorPayMethod method,
  required String name,
  required String email,
  required String phone,
  required String reference,
}) =>
    [eventId, tierId, quantity, method.db, name.trim(), email.trim().toLowerCase(), phone.trim(), reference.trim()].join('\u0001');

/// What the database answers to a sale.
class DoorSale {
  const DoorSale({required this.orderId, required this.ticketCode, required this.quantity, required this.amountCents, required this.currency, required this.tierName, required this.available, required this.repeated});

  final String orderId;
  final String ticketCode;
  final int quantity;
  final int amountCents;
  final String currency;
  final String tierName;

  /// How many of that ticket type are left after this sale.
  final int available;

  /// True when the same sale had already been made and nothing new was recorded (a retry, a second tap).
  final bool repeated;
}

DoorSale? parseDoorSale(Map<String, dynamic> row) {
  final id = row['order_id'];
  final code = _text(row['ticket_code']);
  final quantity = _int(row['quantity']);
  final amount = _int(row['amount_cents']);
  if (id is! String || code == null || quantity == null || amount == null) return null;
  return DoorSale(
    orderId: id,
    ticketCode: code,
    quantity: quantity,
    amountCents: amount,
    currency: _text(row['currency']) ?? 'cad',
    tierName: _text(row['tier_name']) ?? 'Ticket',
    available: _int(row['available']) ?? 0,
    repeated: row['repeated'] == true,
  );
}

/// One payment method's part of a shift.
class MethodTotal {
  const MethodTotal({required this.method, required this.sales, required this.tickets, required this.amountCents});

  final DoorPayMethod method;
  final int sales;
  final int tickets;
  final int amountCents;
}

/// The door person's own shift at one event.
class ShiftSummary {
  const ShiftSummary({required this.eventTitle, required this.guestsAdmitted, required this.scansAccepted, required this.sales, this.firstSaleAt, this.lastSaleAt});

  final String eventTitle;

  /// Guests of online tickets this person let in by scanning (the guests they sold tickets to are counted under the sales).
  final int guestsAdmitted;
  final int scansAccepted;
  final List<MethodTotal> sales;
  final DateTime? firstSaleAt;
  final DateTime? lastSaleAt;

  MethodTotal? _of(DoorPayMethod m) {
    for (final s in sales) {
      if (s.method == m) return s;
    }
    return null;
  }

  MethodTotal? get cash => _of(DoorPayMethod.cash);
  MethodTotal? get terminal => _of(DoorPayMethod.terminal);

  int get salesCount => sales.fold(0, (a, s) => a + s.sales);
  int get ticketsSold => sales.fold(0, (a, s) => a + s.tickets);
  int get totalCents => sales.fold(0, (a, s) => a + s.amountCents);
  bool get hasSales => salesCount > 0;
}

ShiftSummary? parseShiftSummary(Map<String, dynamic> row) {
  final sales = <MethodTotal>[];
  final raw = row['sales'];
  if (raw is List) {
    for (final r in raw) {
      if (r is! Map) continue;
      final method = DoorPayMethod.fromDb(r['method']);
      final count = _int(r['sales']);
      final tickets = _int(r['tickets']);
      final amount = _int(r['amount_cents']);
      if (method == null || count == null || tickets == null || amount == null) continue;
      sales.add(MethodTotal(method: method, sales: count, tickets: tickets, amountCents: amount));
    }
  } else if (raw != null) {
    return null;
  }
  return ShiftSummary(
    eventTitle: _text(row['event_title']) ?? '',
    guestsAdmitted: _int(row['guests_admitted']) ?? 0,
    scansAccepted: _int(row['scans_accepted']) ?? 0,
    sales: sales,
    firstSaleAt: row['first_sale_at'] is String ? DateTime.tryParse(row['first_sale_at'] as String)?.toLocal() : null,
    lastSaleAt: row['last_sale_at'] is String ? DateTime.tryParse(row['last_sale_at'] as String)?.toLocal() : null,
  );
}

/// "3 sales · 5 tickets" with the right plural.
String salesTicketsLine(int sales, int tickets) => '$sales ${sales == 1 ? 'sale' : 'sales'} · $tickets ${tickets == 1 ? 'ticket' : 'tickets'}';

/// "7:05 pm".
String shiftTime(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final m = t.minute.toString().padLeft(2, '0');
  return '$h:$m ${t.hour >= 12 ? 'pm' : 'am'}';
}
