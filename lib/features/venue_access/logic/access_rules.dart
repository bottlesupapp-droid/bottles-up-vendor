import 'package:intl/intl.dart';

import '../../floor/logic/bookings_rules.dart' show formatNight;
import '../../night/logic/night_rules.dart' show ReportDocument, ReportRow, ReportSection;
import '../../ops/logic/ops_json.dart';
import '../../owner/logic/setup_forms.dart' show formatDollars;

/// What a club shares with the organizer of an event it hosts, and the organizer's read-only Sales for that event (website repo, 20261117100000_agreement_access.sql).
/// Which things a club has allowed, which of them the database can supply, and what each side may see are the database's rules. This file reads what it sends and words it.

/// The six things a club can share, in the brief's order.
enum AccessKey {
  barSales('bar_sales', 'Bar sales', 'The bar sales figures for the night.'),
  ticketCheckins('ticket_checkins', 'Ticket check-ins', 'How many ticket holders have come in, and when the last one did.'),
  capacity('capacity', 'Capacity', 'The agreed capacity against tickets sold and guests in.'),
  tableSales('table_sales', 'Table sales', 'How many tables the club has booked that night, for how many guests and for how much. No names.'),
  chat('chat', 'Operational chat', 'Talking with the club\'s staff about the night.'),
  settlement('settlement', 'Settlement details', 'What is owed between the event and the club.');

  const AccessKey(this.value, this.label, this.explanation);

  final String value;
  final String label;
  final String explanation;

  static AccessKey? parse(String? v) {
    for (final k in AccessKey.values) {
      if (k.value == v) return k;
    }
    return null;
  }
}

/// One of the six, as the club has set it.
class AccessGrant {
  const AccessGrant({required this.key, required this.allowed, required this.available, this.grantedAt, this.grantedByName, this.data});

  final AccessKey key;

  /// The club has allowed it (and its agreement is in force).
  final bool allowed;

  /// The database can supply it today. A thing that is allowed but not available is recorded, and shown as such, never as connected.
  final bool available;
  final DateTime? grantedAt;
  final String? grantedByName;

  /// What the club shares, when it is allowed and available (organizer's Sales only).
  final Map<String, dynamic>? data;

  /// "Shared", "Allowed, not available yet" or "Not shared".
  String get stateLabel => !allowed ? 'Not shared' : (available ? 'Shared' : 'Allowed, not available yet');
}

AccessGrant? parseAccessGrant(Object? raw) {
  if (raw is! Map) return null;
  final m = Map<String, dynamic>.from(raw);
  final key = AccessKey.parse(opsStr(m, 'key'));
  if (key == null) return null;
  return AccessGrant(
    key: key,
    allowed: opsBool(m, 'allowed'),
    available: opsBool(m, 'available'),
    grantedAt: opsTime(m, 'granted_at'),
    grantedByName: opsStr(m, 'granted_by_name'),
    data: m['data'] is Map ? Map<String, dynamic>.from(m['data'] as Map) : null,
  );
}

List<AccessGrant> _grants(Object? list) => [
      if (list is List)
        for (final g in list)
          if (parseAccessGrant(g) != null) parseAccessGrant(g)!,
    ];

/// One agreement's six things, for either side of it.
class AgreementGrants {
  const AgreementGrants({required this.agreementId, required this.status, required this.side, required this.inForce, required this.canChange, required this.grants});

  final String agreementId;
  final String status;

  /// 'organizer' or 'venue'.
  final String side;

  /// The agreement is active (or has a newer version waiting), so what is allowed is shared.
  final bool inForce;

  /// The viewer is the club and the agreement is in force.
  final bool canChange;
  final List<AccessGrant> grants;
}

AgreementGrants? parseAgreementGrants(Map<String, dynamic> r) {
  final id = opsStr(r, 'agreement_id');
  final grants = _grants(r['grants']);
  if (id == null || grants.isEmpty) return null;
  return AgreementGrants(agreementId: id, status: opsStr(r, 'status') ?? '', side: opsStr(r, 'side') ?? 'organizer', inForce: opsBool(r, 'in_force'), canChange: opsBool(r, 'can_change'), grants: grants);
}

/// A row of the organizer's "Your Venue Access" panel: one event at one club.
class VenueAccessRow {
  const VenueAccessRow({required this.agreementId, required this.eventId, required this.eventTitle, required this.venueName, required this.status, required this.inForce, required this.grants, this.eventStart});

  final String agreementId;
  final String eventId;
  final String eventTitle;
  final DateTime? eventStart;
  final String venueName;
  final String status;
  final bool inForce;
  final List<AccessGrant> grants;

  int get allowedCount => grants.where((g) => g.allowed).length;
}

VenueAccessRow? parseVenueAccessRow(Map<String, dynamic> r) {
  final id = opsStr(r, 'agreement_id');
  final event = opsStr(r, 'event_id');
  if (id == null || event == null) return null;
  return VenueAccessRow(
    agreementId: id,
    eventId: event,
    eventTitle: opsStr(r, 'event_title') ?? 'Event',
    eventStart: opsTime(r, 'event_start'),
    venueName: opsStr(r, 'venue_name') ?? 'Club',
    status: opsStr(r, 'status') ?? '',
    inForce: opsBool(r, 'in_force'),
    grants: _grants(r['grants']),
  );
}

/// What the agreement's state means for sharing, in a sentence for the panel.
String accessStatusLine(String status, bool inForce) {
  if (inForce) return status == 'changes_pending' ? 'Active (a newer version is waiting to be accepted)' : 'Active';
  return switch (status) {
    'requested' => 'Asked for: the club has not answered yet. Nothing is shared.',
    'negotiating' => 'Being agreed. Nothing is shared until both sides accept.',
    _ => 'Not active. Nothing is shared.',
  };
}

// -------------------------------------------------------------------------------------------------------------------------------------
// The organizer's Sales
// -------------------------------------------------------------------------------------------------------------------------------------

class TierSales {
  const TierSales({required this.name, required this.priceCents, required this.capacity, required this.sold, required this.checkedIn, required this.grossCents, this.currency});

  final String name;
  final int priceCents;
  final int capacity;
  final int sold;
  final int checkedIn;
  final int grossCents;
  final String? currency;
}

class TicketSales {
  const TicketSales({required this.orders, required this.ticketsSold, required this.checkedIn, required this.refundedOrders, required this.refundedCents, required this.currencyMixed, required this.tiers, this.grossCents, this.currency});

  final int orders;
  final int ticketsSold;
  final int checkedIn;
  final int refundedOrders;
  final int refundedCents;

  /// Null when the paid orders are in more than one currency: they are never added.
  final int? grossCents;
  final String? currency;
  final bool currencyMixed;
  final List<TierSales> tiers;
}

class SharedByClub {
  const SharedByClub({required this.agreementId, required this.venueName, required this.status, required this.inForce, required this.grants});

  final String agreementId;
  final String venueName;
  final String status;
  final bool inForce;
  final List<AccessGrant> grants;
}

class EventSales {
  const EventSales({required this.eventTitle, required this.eventStatus, required this.venueName, required this.tickets, required this.clubs, this.eventStart, this.eventEnd, this.eventCapacity, this.generatedAt});

  final String eventTitle;
  final DateTime? eventStart;
  final DateTime? eventEnd;
  final String eventStatus;
  final String venueName;
  final int? eventCapacity;
  final DateTime? generatedAt;
  final TicketSales tickets;
  final List<SharedByClub> clubs;
}

EventSales? parseEventSales(Map<String, dynamic> r) {
  final ev = r['event'];
  final t = r['tickets'];
  if (ev is! Map || t is! Map) return null;
  final e = Map<String, dynamic>.from(ev);
  final tm = Map<String, dynamic>.from(t);
  final tiers = <TierSales>[];
  if (tm['by_tier'] is List) {
    for (final x in tm['by_tier'] as List) {
      if (x is! Map) return null;
      final m = Map<String, dynamic>.from(x);
      final name = opsStr(m, 'tier');
      if (name == null) return null;
      tiers.add(TierSales(name: name, priceCents: opsInt(m, 'price_cents'), capacity: opsInt(m, 'capacity'), sold: opsInt(m, 'sold'), checkedIn: opsInt(m, 'checked_in'), grossCents: opsInt(m, 'gross_cents'), currency: opsStr(m, 'currency')));
    }
  }
  final mixed = opsBool(tm, 'currency_mixed');
  final clubs = <SharedByClub>[];
  if (r['venues'] is List) {
    for (final x in r['venues'] as List) {
      if (x is! Map) return null;
      final m = Map<String, dynamic>.from(x);
      final id = opsStr(m, 'agreement_id');
      if (id == null) return null;
      clubs.add(SharedByClub(agreementId: id, venueName: opsStr(m, 'venue_name') ?? 'Club', status: opsStr(m, 'status') ?? '', inForce: opsBool(m, 'in_force'), grants: _grants(m['grants'])));
    }
  }
  return EventSales(
    eventTitle: opsStr(e, 'title') ?? 'Event',
    eventStart: opsTime(e, 'start'),
    eventEnd: opsTime(e, 'end'),
    eventStatus: opsStr(e, 'status') ?? '',
    venueName: opsStr(e, 'venue_name') ?? '',
    eventCapacity: e['capacity'] == null ? null : opsInt(e, 'capacity'),
    generatedAt: opsTime(r, 'generated_at'),
    tickets: TicketSales(
      orders: opsInt(tm, 'orders'),
      ticketsSold: opsInt(tm, 'tickets_sold'),
      checkedIn: opsInt(tm, 'checked_in'),
      refundedOrders: opsInt(tm, 'refunded_orders'),
      refundedCents: opsInt(tm, 'refunded_cents'),
      currencyMixed: mixed,
      // Money is only ever shown for a single currency, whatever else the answer holds.
      grossCents: mixed || tm['gross_cents'] == null ? null : opsInt(tm, 'gross_cents'),
      currency: mixed ? null : opsStr(tm, 'currency'),
      tiers: tiers,
    ),
    clubs: clubs,
  );
}

String _when(DateTime? t) => t == null ? 'Not set' : DateFormat('EEE MMM d, HH:mm').format(t.toLocal());
String _time(DateTime? t) => t == null ? 'None yet' : DateFormat('HH:mm').format(t.toLocal());
String _plural(int n, String one, String many) => '$n ${n == 1 ? one : many}';

/// The event's status in words. "Published" is the website's word; anything else that is not a draft is shown as it came.
String eventStatusWords(String s) => switch (s) {
      'draft' => 'Draft (private)',
      'published' => 'Published',
      '' => 'Unknown',
      _ => s[0].toUpperCase() + s.substring(1).replaceAll('_', ' '),
    };

/// The rows one club's shared things make, in the brief's order. A thing that is not shared, or not available yet, says so instead of leaving a gap.
List<ReportSection> sharedSections(SharedByClub club) {
  final out = <ReportSection>[];
  if (!club.inForce) {
    out.add(ReportSection('${club.venueName} · not active', [ReportRow('Shared with you', accessStatusLine(club.status, false))]));
    return out;
  }
  final notShared = <ReportRow>[];
  for (final g in club.grants) {
    final d = g.data;
    if (!g.allowed || !g.available || d == null) {
      notShared.add(ReportRow(g.key.label, g.stateLabel));
      continue;
    }
    switch (g.key) {
      case AccessKey.tableSales:
        final mixed = d['currency_mixed'] == true;
        final label = d['currency'] == null ? '' : ' (${d['currency']})';
        out.add(ReportSection('Table sales at ${club.venueName}$label · ${formatNight('${d['night']}')}', [
          ReportRow('Tables booked', '${opsInt(d, 'tables')}'),
          ReportRow('Guests', '${opsInt(d, 'guests')}'),
          if (mixed) const ReportRow('Money', 'Not added: more than one currency') else ...[
            ReportRow('Booked total', formatDollars(opsInt(d, 'booked_cents')), strong: true),
            ReportRow('Paid so far', formatDollars(opsInt(d, 'paid_cents'))),
          ],
        ]));
      case AccessKey.capacity:
        final agreed = d['agreed'] == null ? null : opsInt(d, 'agreed');
        out.add(ReportSection('Capacity at ${club.venueName}', [
          ReportRow('Agreed capacity', agreed == null ? 'Not set in the agreement' : '$agreed'),
          ReportRow('Tickets sold', '${opsInt(d, 'tickets_sold')}'),
          ReportRow('Checked in', '${opsInt(d, 'checked_in')}'),
          if (agreed != null) ReportRow('Room left (agreed less checked in)', '${agreed - opsInt(d, 'checked_in')}'),
        ]));
      case AccessKey.ticketCheckins:
        final last = d['last_check_in_at'] == null ? null : DateTime.tryParse('${d['last_check_in_at']}');
        out.add(ReportSection('Check-ins at ${club.venueName}', [
          ReportRow('Checked in', '${opsInt(d, 'checked_in')} of ${opsInt(d, 'tickets_sold')}'),
          ReportRow('Last check-in', _time(last)),
        ]));
      default:
        notShared.add(ReportRow(g.key.label, g.stateLabel));
    }
  }
  if (notShared.isNotEmpty) out.add(ReportSection('Not available from ${club.venueName}', notShared));
  return out;
}

/// The organizer's report for one event: the same words on the screen and in the PDF. Only what each club has chosen to share is in it.
ReportDocument buildSalesDocument(EventSales s) {
  final t = s.tickets;
  final label = t.currency == null ? '' : ' (${t.currency})';
  final sections = <ReportSection>[
    ReportSection('Event', [
      ReportRow('Event', s.eventTitle),
      ReportRow('Starts', _when(s.eventStart)),
      if (s.eventEnd != null) ReportRow('Ends', _when(s.eventEnd)),
      ReportRow('Status', eventStatusWords(s.eventStatus)),
      if (s.venueName.isNotEmpty) ReportRow('Venue', s.venueName),
      if (s.eventCapacity != null) ReportRow('Capacity set on the event', '${s.eventCapacity}'),
    ]),
    ReportSection('Your tickets$label', [
      ReportRow('Paid orders', '${t.orders}'),
      ReportRow('Tickets sold', '${t.ticketsSold}', strong: true),
      ReportRow('Checked in', '${t.checkedIn}'),
      ReportRow('Gross sales', t.grossCents == null ? 'Not added: more than one currency' : formatDollars(t.grossCents!), strong: true),
      if (t.refundedOrders > 0) ReportRow('Refunded', '${_plural(t.refundedOrders, 'order', 'orders')} · ${t.currencyMixed ? 'amount not added' : formatDollars(t.refundedCents)}'),
    ]),
    if (t.tiers.isNotEmpty)
      ReportSection('By ticket type', [
        for (final x in t.tiers) ReportRow('${x.name} · ${formatDollars(x.priceCents)}${x.currency == null ? '' : ' ${x.currency}'} · ${x.sold} of ${x.capacity} sold, ${x.checkedIn} in', formatDollars(x.grossCents)),
      ]),
  ];
  if (s.clubs.isEmpty) {
    sections.add(const ReportSection('Shared by the club', [ReportRow('Venue', 'No club is linked to this event yet')]));
  }
  for (final c in s.clubs) {
    sections.addAll(sharedSections(c));
  }
  final slug = s.eventTitle.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
  final date = s.eventStart == null ? '' : DateFormat('yyyy-MM-dd').format(s.eventStart!.toLocal());
  return ReportDocument(
    title: 'Event report',
    subtitle: s.eventTitle,
    statusLine: '${s.generatedAt == null ? 'Figures as they stand now' : 'Figures as of ${_time(s.generatedAt)}'}. Only what each club has chosen to share is included.',
    sections: sections,
    fileName: '${slug.isEmpty ? 'event' : slug}${date.isEmpty ? '' : '-$date'}-event-report.pdf',
  );
}
