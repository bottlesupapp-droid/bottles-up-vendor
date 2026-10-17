import 'package:intl/intl.dart';

import '../../ops/logic/ops_json.dart';

/// The organizer's guest list: who bought tickets to their events and how check-in is going. Read-only. Who may read it (only the business
/// that owns the event) and that no email, phone or payment detail comes back are the database's rules.

class TierCount {
  const TierCount({required this.tier, required this.sold, required this.checkedIn});

  final String tier;
  final int sold;
  final int checkedIn;
}

class GuestSummary {
  const GuestSummary({required this.orders, required this.ticketsSold, required this.checkedIn, required this.tiers});

  final int orders;
  final int ticketsSold;
  final int checkedIn;
  final List<TierCount> tiers;

  int get remaining => ticketsSold - checkedIn;

  /// "42 of 156 checked in".
  String get progress => '$checkedIn of $ticketsSold checked in';
}

GuestSummary? parseGuestSummary(Map<String, dynamic> r) {
  final tiers = r['by_tier'];
  return GuestSummary(
    orders: opsInt(r, 'orders'),
    ticketsSold: opsInt(r, 'tickets_sold'),
    checkedIn: opsInt(r, 'checked_in'),
    tiers: [
      if (tiers is List)
        for (final t in tiers)
          if (t is Map) TierCount(tier: t['tier']?.toString() ?? 'Tickets', sold: opsInt(Map<String, dynamic>.from(t), 'sold'), checkedIn: opsInt(Map<String, dynamic>.from(t), 'checked_in')),
    ],
  );
}

class Guest {
  const Guest({required this.orderId, required this.name, required this.quantity, this.ticketCode, this.tier, this.checkedInAt});

  final String orderId;
  final String name;
  final String? ticketCode;
  final String? tier;
  final int quantity;
  final DateTime? checkedInAt;

  bool get checkedIn => checkedInAt != null;

  /// "General · 2 tickets".
  String get ticketLine => '${tier ?? 'Ticket'} · $quantity ${quantity == 1 ? 'ticket' : 'tickets'}';
}

Guest? parseGuest(Map<String, dynamic> r) {
  final id = opsStr(r, 'order_id');
  if (id == null) return null;
  return Guest(
    orderId: id,
    name: opsStr(r, 'customer_name') ?? 'Guest',
    ticketCode: opsStr(r, 'ticket_code'),
    tier: opsStr(r, 'tier_name'),
    quantity: opsInt(r, 'quantity') == 0 ? 1 : opsInt(r, 'quantity'),
    checkedInAt: opsTime(r, 'checked_in_at'),
  );
}

String? checkGuestSearch(String text) {
  final t = text.trim();
  if (t.isNotEmpty && t.length < 2) return 'Type at least 2 characters to search.';
  return null;
}

String checkedInLabel(DateTime? at) => at == null ? 'Not checked in' : 'Checked in ${DateFormat('HH:mm').format(at.toLocal())}';
