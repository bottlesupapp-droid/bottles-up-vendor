import 'package:intl/intl.dart';

import '../../night/logic/night_rules.dart' show ReportDocument, ReportRow, ReportSection;
import '../../owner/logic/setup_forms.dart' show formatDollars, parseMoney;
import '../../workspace/models/workspace_role.dart';

// The rules behind Sales Tracking (website repo, 20261121100000_sales_source.sql; brief section 24 and scenario 18). Where a club's sales come from, the closing report the club sends, and how a night's sales are labelled
// so that nothing is counted twice and every figure says where it came from. The database decides who may do what; these only keep the screens from offering what it would refuse, and word what comes back.

/// Where a club's sales come from. Connected POS is not a value: no provider is connected, and an unavailable integration must say so.
enum SalesSource {
  entries('entries', 'BottlesUp entries', 'Sales are what BottlesUp recorded: table bookings, their bottles and the payments taken. Nothing else is added.'),
  upload('upload', 'Closing report upload', 'The club also sends a closing report for each night. It is shown beside what BottlesUp recorded, labelled as the club\'s own figure, and a person other than the sender checks it.');

  const SalesSource(this.wire, this.label, this.blurb);

  final String wire;
  final String label;
  final String blurb;
}

SalesSource? parseSalesSource(Object? v) {
  for (final s in SalesSource.values) {
    if (s.wire == v) return s;
  }
  return null;
}

const posLabel = 'Connected POS';
const posUnavailableText = 'Not available yet: no point-of-sale provider is connected, so there is nothing to connect.';

/// Who changes the source and sends a closing report (the club's owner or manager), and who checks one (the owner or a payment verifier). The database decides; this keeps the buttons honest.
bool canChooseSource(WorkspaceRole role) => role == WorkspaceRole.owner || role == WorkspaceRole.manager;
bool canSendClosingReport(WorkspaceRole role) => canChooseSource(role);
bool canCheckClosingReport(WorkspaceRole role) => role == WorkspaceRole.owner || role == WorkspaceRole.verifier;

enum ClosingReportStatus {
  submitted('submitted', 'Waiting to be checked'),
  reviewed('reviewed', 'Checked'),
  rejected('rejected', 'Not accepted'),
  superseded('superseded', 'Replaced by a newer report');

  const ClosingReportStatus(this.wire, this.label);

  final String wire;
  final String label;
}

ClosingReportStatus? parseClosingReportStatus(Object? v) {
  for (final s in ClosingReportStatus.values) {
    if (s.wire == v) return s;
  }
  return null;
}

DateTime? _time(Object? v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;
int? _int(Object? v) => v is int ? v : (v is num ? v.toInt() : (v is String ? int.tryParse(v) : null));

/// A closing report as the club's list shows it.
class ClosingReport {
  const ClosingReport({
    required this.id,
    required this.night,
    required this.version,
    required this.status,
    required this.periodStart,
    required this.periodEnd,
    required this.grossCents,
    required this.discountCents,
    required this.refundCents,
    required this.netCents,
    required this.includesBottlesUp,
    required this.note,
    required this.submittedAt,
    required this.reviewedAt,
    required this.reviewNote,
    required this.mine,
    required this.canReview,
  });

  final String id;

  /// The business night, "2026-11-01".
  final String night;
  final int version;
  final ClosingReportStatus status;
  final DateTime periodStart;
  final DateTime periodEnd;
  final int grossCents;
  final int discountCents;
  final int refundCents;
  final int netCents;
  final bool includesBottlesUp;
  final String? note;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;
  final String? reviewNote;

  /// This person sent it (so they cannot check it).
  final bool mine;

  /// The database says this person may accept or refuse it now.
  final bool canReview;
}

ClosingReport? parseClosingReport(Map<String, dynamic> row) {
  final status = parseClosingReportStatus(row['status']);
  final start = _time(row['period_start']);
  final end = _time(row['period_end']);
  final gross = _int(row['gross_cents']);
  if (row['id'] is! String || row['business_night'] is! String || status == null || start == null || end == null || gross == null) return null;
  return ClosingReport(
    id: row['id'] as String,
    night: row['business_night'] as String,
    version: _int(row['version']) ?? 1,
    status: status,
    periodStart: start,
    periodEnd: end,
    grossCents: gross,
    discountCents: _int(row['discount_cents']) ?? 0,
    refundCents: _int(row['refund_cents']) ?? 0,
    netCents: _int(row['net_cents']) ?? gross,
    includesBottlesUp: row['includes_bottlesup'] == true,
    note: row['note'] is String ? row['note'] as String : null,
    submittedAt: _time(row['submitted_at']),
    reviewedAt: _time(row['reviewed_at']),
    reviewNote: row['review_note'] is String ? row['review_note'] as String : null,
    mine: row['mine'] == true,
    canReview: row['can_review'] == true,
  );
}

/// "Fri Oct 30" for a night written "2026-10-30".
String nightText(String night) {
  final d = DateTime.tryParse(night);
  return d == null ? night : DateFormat('EEE MMM d').format(d);
}

/// "8:00 PM to 4:00 AM".
String periodText(DateTime start, DateTime end) => '${DateFormat('h:mm a').format(start)} to ${DateFormat('h:mm a').format(end)}';

/// One line of a closing report in the club's list: "Fri Oct 30 · version 2 · $840.00 net · Checked".
String reportSummaryLine(ClosingReport r) => '${nightText(r.night)} · version ${r.version} · ${formatDollars(r.netCents)} net · ${r.status.label}';

// ---------------------------------------------------------------------------
// Sending a closing report
// ---------------------------------------------------------------------------

/// What the person has typed to send a closing report. [startMinutes] and [endMinutes] are minutes after midnight: the period starts that evening and ends at [endMinutes] (the next morning when it is earlier
/// than the start).
class ClosingReportForm {
  const ClosingReportForm({
    required this.night,
    this.startMinutes = 20 * 60,
    this.endMinutes = 4 * 60,
    this.grossText = '',
    this.discountText = '',
    this.refundText = '',
    this.includesBottlesUp,
    this.note = '',
  });

  /// "2026-10-30".
  final String night;
  final int startMinutes;
  final int endMinutes;
  final String grossText;
  final String discountText;
  final String refundText;

  /// Null until the person says: the figures either include what BottlesUp recorded or they do not.
  final bool? includesBottlesUp;
  final String note;

  ClosingReportForm copy({String? night, int? startMinutes, int? endMinutes, String? grossText, String? discountText, String? refundText, Object? includesBottlesUp = _keep, String? note}) =>
      ClosingReportForm(
        night: night ?? this.night,
        startMinutes: startMinutes ?? this.startMinutes,
        endMinutes: endMinutes ?? this.endMinutes,
        grossText: grossText ?? this.grossText,
        discountText: discountText ?? this.discountText,
        refundText: refundText ?? this.refundText,
        includesBottlesUp: identical(includesBottlesUp, _keep) ? this.includesBottlesUp : includesBottlesUp as bool?,
        note: note ?? this.note,
      );

  static const Object _keep = Object();

  int? get grossCents => parseMoney(grossText);
  int get discountCents => discountText.trim().isEmpty ? 0 : (parseMoney(discountText) ?? -1);
  int get refundCents => refundText.trim().isEmpty ? 0 : (parseMoney(refundText) ?? -1);

  DateTime? get _nightDate => DateTime.tryParse(night);

  /// The period as moments in time, in the phone's own time zone.
  (DateTime, DateTime)? period() {
    final d = _nightDate;
    if (d == null) return null;
    final start = DateTime(d.year, d.month, d.day, startMinutes ~/ 60, startMinutes % 60);
    var end = DateTime(d.year, d.month, d.day, endMinutes ~/ 60, endMinutes % 60);
    if (!end.isAfter(start)) end = end.add(const Duration(days: 1));
    return (start, end);
  }

  /// What is wrong, in a sentence, or null when it can be sent. The database checks all of it again.
  String? problem({DateTime? now}) {
    final today = now ?? DateTime.now();
    final d = _nightDate;
    if (d == null) return 'Which night is the report for?';
    if (d.isAfter(DateTime(today.year, today.month, today.day).add(const Duration(days: 1)))) return 'That night has not happened yet.';
    if (startMinutes == endMinutes) return 'The period must end after it starts.';
    final gross = grossCents;
    if (gross == null) return grossText.trim().isEmpty ? 'Enter the gross sales for the period.' : 'Enter the gross sales as an amount like 1250.00.';
    if (discountCents < 0) return 'Enter the discounts as an amount like 50.00, or leave them empty.';
    if (refundCents < 0) return 'Enter the refunds as an amount like 50.00, or leave them empty.';
    if (discountCents + refundCents > gross) return 'Discounts and refunds cannot be more than the gross sales.';
    if (includesBottlesUp == null) return 'Say whether these figures include what BottlesUp recorded.';
    if (note.trim().length > 300) return 'The note is at most 300 characters.';
    return null;
  }

  Map<String, dynamic> params(String venueId) {
    final p = period()!;
    return {
      'p_venue': venueId,
      'p_night': night,
      'p_period_start': p.$1.toUtc().toIso8601String(),
      'p_period_end': p.$2.toUtc().toIso8601String(),
      'p_gross_cents': grossCents,
      'p_discount_cents': discountCents,
      'p_refund_cents': refundCents,
      'p_includes_bottlesup': includesBottlesUp,
      'p_note': note.trim().isEmpty ? null : note.trim(),
    };
  }
}

// ---------------------------------------------------------------------------
// A night's sales: two labelled blocks, never added together
// ---------------------------------------------------------------------------

/// What BottlesUp recorded for the night.
class RecordedSales {
  const RecordedSales({
    required this.label,
    required this.basis,
    required this.bookings,
    required this.grossCents,
    required this.discountCents,
    required this.refundCents,
    required this.netCents,
    required this.collectedCents,
    required this.unpaidCents,
    required this.asOf,
  });

  final String label;
  final String basis;
  final int bookings;
  final int grossCents;
  final int discountCents;
  final int refundCents;
  final int netCents;
  final int collectedCents;
  final int unpaidCents;
  final DateTime? asOf;
}

/// The club's own closing report for the night, as the night's sales show it.
class VenueReportedSales {
  const VenueReportedSales({
    required this.label,
    required this.basis,
    required this.version,
    required this.status,
    required this.periodStart,
    required this.periodEnd,
    required this.grossCents,
    required this.discountCents,
    required this.refundCents,
    required this.netCents,
    required this.includesBottlesUp,
    required this.barAndOtherCents,
    required this.smallerThanRecorded,
    required this.submittedAt,
    required this.reviewedAt,
    required this.verification,
  });

  final String label;
  final String basis;
  final int version;
  final ClosingReportStatus status;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final int grossCents;
  final int discountCents;
  final int refundCents;
  final int netCents;
  final bool includesBottlesUp;

  /// The report's net less BottlesUp's net when the report includes it (never below 0); the whole net when it does not.
  final int barAndOtherCents;
  final bool smallerThanRecorded;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;
  final String verification;
}

class NightSales {
  const NightSales({required this.night, required this.source, required this.sourceLabel, required this.recorded, required this.reported});

  final String night;
  final SalesSource source;
  final String sourceLabel;
  final RecordedSales recorded;
  final VenueReportedSales? reported;
}

NightSales? parseNightSales(Map<String, dynamic> j) {
  final source = parseSalesSource(j['source']);
  final r = j['recorded'];
  if (source == null || r is! Map || j['business_night'] is! String) return null;
  final recorded = RecordedSales(
    label: r['label'] is String ? r['label'] as String : 'Recorded sales',
    basis: r['basis'] is String ? r['basis'] as String : '',
    bookings: _int(r['bookings']) ?? 0,
    grossCents: _int(r['gross_cents']) ?? 0,
    discountCents: _int(r['discount_cents']) ?? 0,
    refundCents: _int(r['refund_cents']) ?? 0,
    netCents: _int(r['net_cents']) ?? 0,
    collectedCents: _int(r['collected_cents']) ?? 0,
    unpaidCents: _int(r['unpaid_cents']) ?? 0,
    asOf: _time(r['as_of']),
  );
  VenueReportedSales? reported;
  final v = j['venue_reported'];
  if (v is Map) {
    final status = parseClosingReportStatus(v['status']);
    if (status != null) {
      reported = VenueReportedSales(
        label: v['label'] is String ? v['label'] as String : 'Venue-reported sales',
        basis: v['basis'] is String ? v['basis'] as String : '',
        version: _int(v['version']) ?? 1,
        status: status,
        periodStart: _time(v['period_start']),
        periodEnd: _time(v['period_end']),
        grossCents: _int(v['gross_cents']) ?? 0,
        discountCents: _int(v['discount_cents']) ?? 0,
        refundCents: _int(v['refund_cents']) ?? 0,
        netCents: _int(v['net_cents']) ?? 0,
        includesBottlesUp: v['includes_bottlesup'] == true,
        barAndOtherCents: _int(v['bar_and_other_cents']) ?? 0,
        smallerThanRecorded: v['smaller_than_recorded'] == true,
        submittedAt: _time(v['submitted_at']),
        reviewedAt: _time(v['reviewed_at']),
        verification: v['verification'] is String ? v['verification'] as String : status.label,
      );
    }
  }
  return NightSales(night: j['business_night'] as String, source: source, sourceLabel: j['source_label'] is String ? j['source_label'] as String : source.label, recorded: recorded, reported: reported);
}

/// One row of a labelled block.
class SalesLine {
  const SalesLine(this.label, this.value, {this.strong = false});

  final String label;
  final String value;
  final bool strong;
}

String _at(DateTime? t) => t == null ? '' : DateFormat('MMM d, h:mm a').format(t);

List<SalesLine> recordedLines(RecordedSales r) => [
      SalesLine('Booked, before discounts', formatDollars(r.grossCents)),
      SalesLine('Discounts', formatDollars(r.discountCents)),
      SalesLine('Refunds paid out', formatDollars(r.refundCents)),
      SalesLine('Net of refunds', formatDollars(r.netCents), strong: true),
      SalesLine('Collected', formatDollars(r.collectedCents)),
      SalesLine('Not yet collected', formatDollars(r.unpaidCents)),
      SalesLine('Worked out', r.asOf == null ? 'just now' : _at(r.asOf)),
    ];

List<SalesLine> reportedLines(VenueReportedSales v) => [
      if (v.periodStart != null && v.periodEnd != null) SalesLine('Period', periodText(v.periodStart!, v.periodEnd!)),
      SalesLine('Gross', formatDollars(v.grossCents)),
      SalesLine('Discounts', formatDollars(v.discountCents)),
      SalesLine('Refunds', formatDollars(v.refundCents)),
      SalesLine('Net', formatDollars(v.netCents), strong: true),
      SalesLine('Includes what BottlesUp recorded', v.includesBottlesUp ? 'Yes' : 'No'),
      if (v.includesBottlesUp) SalesLine('Bar and other, without BottlesUp\'s', formatDollars(v.barAndOtherCents), strong: true),
      SalesLine('Sent', _at(v.submittedAt)),
      SalesLine('Checked', v.status == ClosingReportStatus.submitted ? 'Waiting to be checked' : '${v.verification}${v.reviewedAt == null ? '' : ', ${_at(v.reviewedAt)}'}'),
    ];

/// What to say under the two blocks.
const sourcesFooter = 'The two are never added together. Venue-reported sales are the club\'s own end-of-night figure, not live bar sales.';
const smallerThanRecordedText = 'This report is smaller than what BottlesUp recorded for the night, so it cannot include all of it. Check it before accepting.';

/// What to say when a club on closing report upload has not sent one for the night.
const noReportYetText = 'No closing report has been sent for this night.';

/// The whole block as text, for the PDF and the screen to share: the sections in the order they are shown.
List<(String title, String basis, List<SalesLine> lines)> salesSections(NightSales s) => [
      (s.recorded.label, s.recorded.basis, recordedLines(s.recorded)),
      if (s.reported != null) (s.reported!.label, s.reported!.basis, reportedLines(s.reported!)),
    ];

/// The night's report with the labelled sales added at the end, for the screen and the PDF alike. Without [sales] (the server cannot answer, or this role may not read them) the report is returned unchanged.
/// A report the club sent that is smaller than what BottlesUp recorded gets a row that says to check it.
ReportDocument documentWithSales(ReportDocument doc, NightSales? sales) {
  if (sales == null) return doc;
  final extra = <ReportSection>[
    for (final (title, basis, lines) in salesSections(sales))
      ReportSection(title, [
        if (basis.isNotEmpty) ReportRow('What this is', basis),
        for (final l in lines) ReportRow(l.label, l.value, strong: l.strong),
        if (sales.reported != null && title == sales.reported!.label && sales.reported!.smallerThanRecorded) const ReportRow('Check this report', smallerThanRecordedText, strong: true),
      ]),
    if (sales.source == SalesSource.upload && sales.reported == null) const ReportSection('Venue-reported sales', [ReportRow('Closing report', noReportYetText)]),
    ReportSection('Reading the sales', [ReportRow('This club\'s source', sales.sourceLabel), const ReportRow('Note', sourcesFooter)]),
  ];
  return ReportDocument(title: doc.title, subtitle: doc.subtitle, statusLine: doc.statusLine, sections: [...doc.sections, ...extra], fileName: doc.fileName);
}
