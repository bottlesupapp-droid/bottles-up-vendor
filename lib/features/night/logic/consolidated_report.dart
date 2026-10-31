import 'package:intl/intl.dart';

import '../../floor/logic/bookings_rules.dart' show formatNight;
import '../../ops/logic/ops_json.dart';
import '../../owner/logic/setup_forms.dart' show formatDollars;
import 'night_rules.dart';

/// The owner's report for one business night across every club of the business (website repo, 20261115100000_owner_night_report.sql).
/// The database adds the clubs up and decides whether they can be added at all (more than one currency: no total); this file reads what
/// it sent and words it.

class ClubReport {
  const ClubReport({required this.venueId, required this.venueName, required this.currencies, required this.report});

  final String venueId;
  final String venueName;

  /// The currencies this club's paid bookings of the night are in, lower case ("cad"); empty when it had none.
  final List<String> currencies;

  /// The club's own nightly report as its manager and the owner see it: final once the night is closed, otherwise preliminary.
  final NightReport report;

  /// "CAD" for a club that sold in one currency, "mixed currencies" for more than one, nothing when it sold nothing.
  String? get currencyLabel => currencies.isEmpty ? null : (currencies.length == 1 ? currencies.single.toUpperCase() : 'mixed currencies');
}

class ConsolidatedReport {
  const ConsolidatedReport({
    required this.orgName,
    required this.night,
    required this.venuesTotal,
    required this.venuesFinal,
    required this.currencyMixed,
    required this.currencies,
    required this.venues,
    this.currency,
    this.totals,
    this.generatedAt,
  });

  final String orgName;
  final String night;
  final DateTime? generatedAt;
  final int venuesTotal;

  /// How many clubs have closed the night, so a combined figure is never mistaken for a closed one.
  final int venuesFinal;

  /// "CAD" when every paid booking of the night is in one currency; null when they are not (then there is no total).
  final String? currency;
  final bool currencyMixed;
  final List<String> currencies;

  /// The business's totals for the night. Null when the clubs sold in more than one currency: dollars and pounds are never added.
  final Map<String, int>? totals;
  final List<ClubReport> venues;

  bool get allFinal => venuesTotal > 0 && venuesFinal == venuesTotal;
}

/// Null when the answer cannot be trusted: no night, a club whose report cannot be read (leaving it out would make the totals look
/// wrong), or a club count that does not match the clubs sent.
ConsolidatedReport? parseConsolidatedReport(Map<String, dynamic> r) {
  final night = opsStr(r, 'business_night');
  if (night == null) return null;
  final raw = r['venues'];
  if (raw is! List) return null;
  final clubs = <ClubReport>[];
  for (final v in raw) {
    if (v is! Map) return null;
    final m = Map<String, dynamic>.from(v);
    final id = opsStr(m, 'venue_id');
    final report = m['report'] is Map ? parseNightReport(Map<String, dynamic>.from(m['report'] as Map)) : null;
    if (id == null || report == null) return null;
    clubs.add(ClubReport(
      venueId: id,
      venueName: opsStr(m, 'venue_name') ?? report.venueName,
      currencies: [if (m['currencies'] is List) for (final c in m['currencies'] as List) c.toString()],
      report: report,
    ));
  }
  final total = opsInt(r, 'venues_total');
  if (total != clubs.length) return null;

  final mixed = opsBool(r, 'currency_mixed');
  final t = r['totals'];
  // A total is only ever shown for a single currency, whatever else the answer holds.
  if (!mixed && t is! Map) return null;
  return ConsolidatedReport(
    orgName: opsStr(r, 'org_name') ?? 'Your business',
    night: night,
    generatedAt: opsTime(r, 'generated_at'),
    venuesTotal: total,
    venuesFinal: opsInt(r, 'venues_final'),
    currency: mixed ? null : opsStr(r, 'currency'),
    currencyMixed: mixed,
    currencies: [if (r['currencies'] is List) for (final c in r['currencies'] as List) c.toString()],
    totals: mixed || t is! Map ? null : {for (final e in t.entries) e.key.toString(): e.value is num ? (e.value as num).toInt() : (int.tryParse(e.value.toString()) ?? 0)},
    venues: clubs,
  );
}

String _slug(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');

/// The report as it is shown and printed: the same words on the screen and in the PDF.
ReportDocument buildConsolidatedDocument(ConsolidatedReport r) {
  final sections = <ReportSection>[];
  final t = r.totals;
  int n(String key) => t?[key] ?? 0;
  String d(String key) => formatDollars(n(key));
  final label = r.currency == null ? '' : ' (${r.currency})';

  if (r.currencyMixed) {
    sections.add(ReportSection('Totals not added', [
      ReportRow('Currencies sold in', r.currencies.map((c) => c.toUpperCase()).join(', ')),
      const ReportRow('Combined total', 'Not shown'),
      const ReportRow('Why', 'Different currencies are never added together'),
    ]));
  } else if (t != null) {
    sections.addAll([
      ReportSection('Tables and guests$label', [
        ReportRow('Tables booked', '${n('tables')}'),
        ReportRow('Guests', '${n('guests')}'),
        ReportRow('Guests seated (tables)', '${n('seated')}'),
      ]),
      ReportSection('Sales$label', [
        ReportRow('Booked total', d('booked_cents'), strong: true),
        ReportRow('Paid so far', d('paid_cents')),
        ReportRow('Balance still due', d('balance_cents')),
        ReportRow('Discounts', d('discount_cents')),
      ]),
      ReportSection('Collected at the club$label', [
        ReportRow('Payments', '${n('payments')}'),
        ReportRow('Collected', d('collected_cents'), strong: true),
        ReportRow('Cash', d('cash_cents')),
        ReportRow('Card (debit, credit and the card part of splits)', d('card_cents')),
        ReportRow('Cash counted at handover', d('cash_counted_cents')),
        ReportRow('Cash shortages', d('shortage_cents')),
        ReportRow('Cash overages', d('overage_cents')),
        ReportRow('Cash still held by staff', d('held_cents')),
      ]),
      ReportSection('Bottle orders$label', [
        ReportRow('Bottles ordered', '${n('bottle_lines')}'),
        ReportRow('Value', d('bottle_value_cents'), strong: true),
        ReportRow('Served', '${n('bottles_served')}'),
      ]),
      ReportSection('Needing attention', [
        ReportRow('Payments not yet verified', '${n('unverified')}'),
        ReportRow('Disputed by the guest', '${n('disputed')}'),
        ReportRow('Without a receipt photo', '${n('no_receipt')}'),
        ReportRow('Flagged payments still open', '${n('flags_open')}'),
        ReportRow('Requests from tables still open', '${n('requests_open')}'),
        ReportRow('Security alerts not resolved', '${n('alerts_unresolved')}'),
        ReportRow('Nights closed with exceptions', '${n('closed_with_exceptions')}'),
      ]),
    ]);
  }

  // Side by side: one line per club, then each club's own figures.
  String clubFigures(ClubReport c) {
    final b = c.report.sections['bookings'];
    if (b == null) return 'No figures';
    final money = formatDollars(opsInt(b, 'total_cents'));
    final tables = opsInt(b, 'count');
    return '$tables ${tables == 1 ? 'table' : 'tables'} · $money';
  }

  if (r.venues.isNotEmpty) {
    sections.add(ReportSection('By club', [
      for (final c in r.venues) ReportRow('${c.venueName} · ${c.report.isFinal ? 'FINAL' : 'PRELIMINARY'}', clubFigures(c)),
    ]));
  }
  for (final c in r.venues) {
    final b = c.report.sections['bookings'];
    final p = c.report.sections['payments'];
    final bt = c.report.sections['bottles'];
    final f = c.report.sections['flags'];
    final cur = c.currencyLabel;
    sections.add(ReportSection('${c.venueName} · ${c.report.isFinal ? 'FINAL' : 'PRELIMINARY'}${cur == null ? '' : ' · $cur'}', [
      if (b != null) ...[
        ReportRow('Tables booked', '${opsInt(b, 'count')}'),
        ReportRow('Guests', '${opsInt(b, 'guests')}'),
        ReportRow('Booked total', formatDollars(opsInt(b, 'total_cents')), strong: true),
        ReportRow('Paid so far', formatDollars(opsInt(b, 'paid_cents'))),
        ReportRow('Balance still due', formatDollars(opsInt(b, 'balance_cents'))),
      ],
      if (p != null) ReportRow('Collected at the club', formatDollars(opsInt(p, 'collected_cents'))),
      if (bt != null) ReportRow('Bottle orders', formatDollars(opsInt(bt, 'value_cents'))),
      if (f != null) ReportRow('Flagged payments still open', '${opsInt(f, 'open')}'),
      if (c.report.isFinal && c.report.exceptions.isNotEmpty) ReportRow('Closed with exceptions', '${c.report.exceptions.length}'),
    ]));
  }

  final String status;
  if (r.venuesTotal == 0) {
    status = 'No venues in this business yet';
  } else if (r.allFinal) {
    status = 'FINAL · every club has closed the night';
  } else {
    final at = r.generatedAt == null ? '' : '; figures as of ${DateFormat('HH:mm').format(r.generatedAt!.toLocal())}';
    status = 'PRELIMINARY · ${r.venuesFinal} of ${r.venuesTotal} clubs have closed the night$at; the totals are not final until every club has';
  }
  final slug = _slug(r.orgName);
  return ReportDocument(
    title: 'All venues',
    subtitle: '${r.orgName} · ${formatNight(r.night)}',
    statusLine: status,
    sections: sections,
    fileName: '${slug.isEmpty ? 'business' : slug}-all-venues-${r.night}-${r.allFinal ? 'final' : 'preliminary'}.pdf',
  );
}
