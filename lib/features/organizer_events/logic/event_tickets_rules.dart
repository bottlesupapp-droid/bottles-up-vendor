// The organizer's tickets for one event: types, prices, quantities and sale dates (developer fix list 22 Nov, item 3).
// Pure Dart, tested without a screen. Each check mirrors the database function that finally decides (`save_org_tier` in the website repo's
// 20261128100000_organizer_tickets.sql), so the form says what is wrong in plain words before anything is sent and the database still
// refuses whatever gets past it.
//
// The rules, in a sentence each: a type has a name (at most 60 characters, not the same as another type of the event), a price (free is
// allowed, at most $10,000.00), a quantity (1 to 100,000) and, if wanted, a time sales start and a time they end (the end after the start,
// and not after the event ends). An event has at most 20 types. Once a type has sold, its name and price are fixed (buyers hold tickets that
// say them) and its quantity cannot go below what has sold. A type that anybody has an order for cannot be removed: stop selling it by
// giving it an end time instead. An event that has ended has no changes at all.

import 'package:intl/intl.dart';

import 'organizer_events_rules.dart';

class TierLimits {
  const TierLimits._();

  static const int name = 60;
  static const int priceMaxCents = 1000000;
  static const int capacityMax = 100000;

  /// Ticket types one event can have.
  static const int perEvent = 20;
}

/// One ticket type, as `list_org_tiers` answers.
class OrgTier {
  const OrgTier({
    required this.tierId,
    required this.name,
    required this.priceCents,
    required this.capacity,
    this.currency = 'cad',
    this.soldCount = 0,
    this.saleStartsAt,
    this.saleEndsAt,
    this.hasSold = false,
    this.hasOrders = false,
    this.requiresAccessCode = false,
  });

  final String tierId;
  final String name;
  final int priceCents;
  final String currency;
  final int capacity;
  final int soldCount;

  /// When sales open and close (UTC instants); empty means no limit.
  final DateTime? saleStartsAt;
  final DateTime? saleEndsAt;

  /// Buyers hold tickets of this type (sold, or paid and refunded): its name and price cannot change.
  final bool hasSold;

  /// Some order, even an unpaid one, points at this type: it cannot be removed.
  final bool hasOrders;

  /// BottlesUp locked it behind an access code in the CMS. The app shows that; it cannot set it.
  final bool requiresAccessCode;

  int get left => capacity - soldCount < 0 ? 0 : capacity - soldCount;
  bool get isFree => priceCents == 0;
}

String? _text(Object? v) => v is String && v.isNotEmpty ? v : null;
int? _int(Object? v) =>
    v is int ? v : (v is num && v == v.roundToDouble() ? v.toInt() : null);
DateTime? _time(Object? v) =>
    v is String ? DateTime.tryParse(v)?.toUtc() : null;

/// One `list_org_tiers` row; a row with no id, no name or no price is dropped.
OrgTier? parseOrgTier(Map<String, dynamic> r) {
  final id = _text(r['tier_id']);
  final name = _text(r['name']);
  final price = _int(r['price_cents']);
  if (id == null || name == null || price == null || price < 0) return null;
  return OrgTier(
    tierId: id,
    name: name,
    priceCents: price,
    currency: _text(r['currency']) ?? 'cad',
    capacity: _int(r['capacity']) ?? 0,
    soldCount: _int(r['sold_count']) ?? 0,
    saleStartsAt: _time(r['sale_starts_at']),
    saleEndsAt: _time(r['sale_ends_at']),
    hasSold: r['has_sold'] == true,
    hasOrders: r['has_orders'] == true,
    requiresAccessCode: r['requires_access_code'] == true,
  );
}

// ---------------------------------------------------------------------------
// Money
// ---------------------------------------------------------------------------

/// "$25.00", or "Free" for nothing.
String formatTierPrice(int cents) =>
    cents == 0 ? 'Free' : '\$${(cents / 100).toStringAsFixed(2)}';

/// The price as typed ("25", "25.5", "25.50", "0") in cents; null when it is not a price. At most two decimals, no signs, no separators.
int? parsePriceCents(String text) {
  final t = text.trim();
  final m = RegExp(r'^(\d{1,7})(?:\.(\d{1,2}))?$').firstMatch(t);
  if (m == null) return null;
  final dollars = int.parse(m.group(1)!);
  final cents =
      m.group(2) == null ? 0 : int.parse(m.group(2)!.padRight(2, '0'));
  return dollars * 100 + cents;
}

/// A price for the box when changing a type: "25" for $25.00, "25.50" otherwise.
String priceBoxText(int cents) =>
    cents % 100 == 0 ? '${cents ~/ 100}' : (cents / 100).toStringAsFixed(2);

// ---------------------------------------------------------------------------
// The form
// ---------------------------------------------------------------------------

/// Text is as typed into the boxes; `starts` and `ends` are the person's own clock, as the pickers give them.
class TierForm {
  const TierForm({
    this.name = '',
    this.price = '',
    this.capacity = '',
    this.starts,
    this.ends,
  });

  final String name;
  final String price;
  final String capacity;
  final DateTime? starts;
  final DateTime? ends;
}

TierForm tierFormFrom(OrgTier t) => TierForm(
  name: t.name,
  price: priceBoxText(t.priceCents),
  capacity: '${t.capacity}',
  starts: t.saleStartsAt?.toLocal(),
  ends: t.saleEndsAt?.toLocal(),
);

/// When the event stops being open to ticket changes: its end, or [openEndedHours] after it starts (the rule the database uses too).
DateTime eventClosesAt(OrgEvent e) =>
    e.endDate ?? e.startDate.add(const Duration(hours: openEndedHours));

/// The tickets of an event that has ended cannot be changed.
bool ticketsLocked(OrgEvent e, DateTime now) => eventClosesAt(e).isBefore(now);

String _tidy(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

/// Plain-language problems with the form; an empty list means it can be sent. [existing] is the type being changed (null when adding),
/// [others] every type of the event (to refuse the same name twice and the 21st type).
List<String> validateTierForm(
  TierForm f, {
  required OrgEvent event,
  OrgTier? existing,
  List<OrgTier> others = const [],
}) {
  final p = <String>[];
  final name = _tidy(f.name);

  if (name.isEmpty) {
    p.add('Give the ticket type a name.');
  } else if (name.length > TierLimits.name) {
    p.add('The name must be ${TierLimits.name} characters or fewer.');
  } else if (others.any(
    (o) =>
        o.tierId != existing?.tierId &&
        _tidy(o.name).toLowerCase() == name.toLowerCase(),
  )) {
    p.add('This event already has a ticket type with that name.');
  }

  final price = parsePriceCents(f.price);
  if (f.price.trim().isEmpty) {
    p.add('Set a price. Use 0 for a free ticket.');
  } else if (price == null) {
    p.add('The price must be an amount like 25 or 25.50.');
  } else if (price > TierLimits.priceMaxCents) {
    p.add(
      'The price can be at most \$${(TierLimits.priceMaxCents / 100).toStringAsFixed(2)}.',
    );
  }

  final capacityText = f.capacity.trim();
  final capacity =
      RegExp(r'^\d{1,9}$').hasMatch(capacityText)
          ? int.parse(capacityText)
          : null;
  if (capacityText.isEmpty) {
    p.add('Say how many tickets there are.');
  } else if (capacity == null ||
      capacity < 1 ||
      capacity > TierLimits.capacityMax) {
    p.add(
      'The quantity must be a whole number from 1 to ${TierLimits.capacityMax}.',
    );
  } else if (existing != null && capacity < existing.soldCount) {
    p.add(
      'The quantity cannot be lower than the ${existing.soldCount} tickets already sold.',
    );
  }

  final closes = eventClosesAt(event);
  if (f.starts != null && f.ends != null && !f.ends!.isAfter(f.starts!)) {
    p.add('Sales must end after they start.');
  }
  if (f.ends != null && f.ends!.isAfter(closes)) {
    p.add('Sales cannot end after the event ends.');
  }
  if (f.starts != null && !f.starts!.isBefore(closes)) {
    p.add('Sales cannot start once the event has ended.');
  }

  if (existing == null && others.length >= TierLimits.perEvent) {
    p.add('An event can have at most ${TierLimits.perEvent} ticket types.');
  }
  return p;
}

/// What is sent: the fields the form shows, and nothing else. Times go as UTC instants, which carry their time zone. Empty sale times are sent
/// as null so they can be cleared. Only call this when [validateTierForm] returned nothing.
Map<String, dynamic> tierPayload(TierForm f) => {
  'name': _tidy(f.name),
  'price_cents': parsePriceCents(f.price),
  'capacity': int.parse(f.capacity.trim()),
  'sale_starts_at': f.starts?.toUtc().toIso8601String(),
  'sale_ends_at': f.ends?.toUtc().toIso8601String(),
};

// ---------------------------------------------------------------------------
// What a card says
// ---------------------------------------------------------------------------

final DateFormat _when = DateFormat('EEE, MMM d, h:mm a', 'en_US');

/// Where this type's sales stand at [now], in a line: "Sales open until Fri, Dec 11, 10:00 PM", "Sales open from ...", "Sales ended", ... or
/// "On sale" when it has no dates.
String saleSummary(OrgTier t, DateTime now) {
  final start = t.saleStartsAt;
  final end = t.saleEndsAt;
  if (start != null && now.isBefore(start)) {
    return end == null
        ? 'Sales open ${_when.format(start.toLocal())}'
        : 'Sales open ${_when.format(start.toLocal())} to ${_when.format(end.toLocal())}';
  }
  if (end != null && !now.isBefore(end)) {
    return 'Sales ended ${_when.format(end.toLocal())}';
  }
  if (end != null) return 'On sale until ${_when.format(end.toLocal())}';
  return 'On sale';
}
