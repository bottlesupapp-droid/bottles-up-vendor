import '../../floor/logic/bookings_rules.dart' show addDays, currentNight, formatNight, formatNightShort;
import '../../ops/logic/ops_json.dart';
import '../../owner/logic/setup_forms.dart' show formatDollars;

/// The owner's Money tab: each club's totals for a range of nights. Who may see them (the owner only) and how each figure is worked out
/// (a correction replaces the payment it corrects) are the database's rules; this file reads what it sends and words it.

class VenueMoney {
  const VenueMoney({
    required this.venueId,
    required this.name,
    required this.tables,
    required this.guests,
    required this.bookedCents,
    required this.paidCents,
    required this.balanceCents,
    required this.cashCents,
    required this.cardCents,
    required this.shortageCents,
    required this.overageCents,
    required this.flagsOpen,
    required this.nightsClosed,
  });

  final String venueId;
  final String name;
  final int tables;
  final int guests;
  final int bookedCents;
  final int paidCents;
  final int balanceCents;
  final int cashCents;
  final int cardCents;
  final int shortageCents;
  final int overageCents;
  final int flagsOpen;
  final int nightsClosed;

  /// What was taken at the club (cash and card).
  int get collectedCents => cashCents + cardCents;
  bool get quiet => tables == 0 && collectedCents == 0;
}

VenueMoney? parseVenueMoney(Map<String, dynamic> r) {
  final id = opsStr(r, 'venue_id');
  if (id == null) return null;
  return VenueMoney(
    venueId: id,
    name: opsStr(r, 'venue_name') ?? 'Club',
    tables: opsInt(r, 'tables'),
    guests: opsInt(r, 'guests'),
    bookedCents: opsInt(r, 'booked_cents'),
    paidCents: opsInt(r, 'paid_cents'),
    balanceCents: opsInt(r, 'balance_cents'),
    cashCents: opsInt(r, 'cash_cents'),
    cardCents: opsInt(r, 'card_cents'),
    shortageCents: opsInt(r, 'shortage_cents'),
    overageCents: opsInt(r, 'overage_cents'),
    flagsOpen: opsInt(r, 'flags_open'),
    nightsClosed: opsInt(r, 'nights_closed'),
  );
}

/// The business as a whole: every club added up.
VenueMoney totalOf(List<VenueMoney> clubs) => VenueMoney(
      venueId: 'total',
      name: 'All clubs',
      tables: clubs.fold(0, (s, c) => s + c.tables),
      guests: clubs.fold(0, (s, c) => s + c.guests),
      bookedCents: clubs.fold(0, (s, c) => s + c.bookedCents),
      paidCents: clubs.fold(0, (s, c) => s + c.paidCents),
      balanceCents: clubs.fold(0, (s, c) => s + c.balanceCents),
      cashCents: clubs.fold(0, (s, c) => s + c.cashCents),
      cardCents: clubs.fold(0, (s, c) => s + c.cardCents),
      shortageCents: clubs.fold(0, (s, c) => s + c.shortageCents),
      overageCents: clubs.fold(0, (s, c) => s + c.overageCents),
      flagsOpen: clubs.fold(0, (s, c) => s + c.flagsOpen),
      nightsClosed: clubs.fold(0, (s, c) => s + c.nightsClosed),
    );

/// A range of nights the owner can pick.
class MoneyRange {
  const MoneyRange(this.id, this.label, this.nights);

  final String id;
  final String label;

  /// How many nights it covers, ending on tonight (1 = tonight only).
  final int nights;

  ({String from, String to}) resolve(DateTime now) {
    final to = currentNight(now);
    return (from: addDays(to, -(nights - 1)), to: to);
  }

  /// "Fri Oct 9" or "Fri Oct 3 to Fri Oct 9".
  String describe(DateTime now) {
    final r = resolve(now);
    return nights == 1 ? formatNight(r.to) : '${formatNightShort(r.from)} to ${formatNightShort(r.to)}';
  }
}

const List<MoneyRange> moneyRanges = [
  MoneyRange('tonight', 'Tonight', 1),
  MoneyRange('last7', 'Last 7 nights', 7),
  MoneyRange('last30', 'Last 30 nights', 30),
];

String differenceLine(VenueMoney m) {
  if (m.shortageCents == 0 && m.overageCents == 0) return 'No cash differences counted.';
  return [if (m.shortageCents > 0) '${formatDollars(m.shortageCents)} short', if (m.overageCents > 0) '${formatDollars(m.overageCents)} over'].join(', ');
}
