import '../../workspace/models/workspace.dart';
import '../../workspace/models/workspace_role.dart';

// E-mailing a report (website repo, 20261119100000_report_emails.sql and the `send-report-email` function). The database decides who may keep a list and who may send a
// report, which addresses a report goes to, and every limit; nothing here decides any of it. This holds the words, the shapes, and the checks that save a trip.

/// The three kinds of report that can be e-mailed. Each has its own list of addresses, so a club-wide report can never reach an organizer's list.
enum ReportKind {
  ownerCombined('owner_combined', 'Combined report'),
  venueNight('venue_night', 'Night report'),
  organizerSales('organizer_sales', 'Event report');

  const ReportKind(this.value, this.label);

  final String value;
  final String label;
}

/// A list holds at most this many addresses (the database enforces it too).
const int maxReportRecipients = 10;

/// Which list: a kind of report for a business, and for the night report also the club.
class ReportListScope {
  const ReportListScope({required this.kind, required this.orgId, this.venueId});

  final ReportKind kind;
  final String orgId;
  final String? venueId;

  Map<String, dynamic> get params => {'p_kind': kind.value, 'p_org': orgId, 'p_venue': venueId};

  @override
  bool operator ==(Object other) => other is ReportListScope && other.kind == kind && other.orgId == orgId && other.venueId == venueId;

  @override
  int get hashCode => Object.hash(kind, orgId, venueId);
}

/// One report that can be e-mailed: which list it goes to and what it is. [ref] is the night (YYYY-MM-DD) or, for an organizer's event report, the event's id.
class ReportTarget {
  const ReportTarget({required this.kind, required this.orgId, this.venueId, this.eventId, required this.ref, required this.fileName});

  final ReportKind kind;
  final String orgId;
  final String? venueId;
  final String? eventId;
  final String ref;
  final String fileName;

  ReportListScope get list => ReportListScope(kind: kind, orgId: orgId, venueId: venueId);

  Map<String, dynamic> get deliveryParams => {'p_kind': kind.value, 'p_org': orgId, 'p_venue': venueId, 'p_event': eventId, 'p_ref': ref, 'p_limit': 8};

  /// The body of the request to the e-mail function (the PDF is added by the service).
  Map<String, dynamic> body({required bool again}) => {
    'kind': kind.value,
    'orgId': orgId,
    'venueId': venueId,
    'eventId': eventId,
    'ref': ref,
    'filename': safeReportFileName(fileName),
    'again': again,
  };

  @override
  bool operator ==(Object other) =>
      other is ReportTarget && other.kind == kind && other.orgId == orgId && other.venueId == venueId && other.eventId == eventId && other.ref == ref && other.fileName == fileName;

  @override
  int get hashCode => Object.hash(kind, orgId, venueId, eventId, ref, fileName);
}

class ReportRecipient {
  const ReportRecipient({required this.id, required this.email});

  final String id;
  final String email;
}

ReportRecipient? parseReportRecipient(Map<String, dynamic> row) {
  final id = row['id']?.toString();
  final email = row['email']?.toString();
  if (id == null || id.isEmpty || email == null || email.isEmpty) return null;
  return ReportRecipient(id: id, email: email);
}

enum DeliveryStatus { pending, sent, failed }

/// One attempt to e-mail one address.
class ReportDelivery {
  const ReportDelivery({required this.email, required this.status, this.error, this.at});

  final String email;
  final DeliveryStatus status;
  final String? error;
  final DateTime? at;
}

ReportDelivery? parseReportDelivery(Map<String, dynamic> row) {
  final email = row['email']?.toString();
  final status = switch (row['status']?.toString()) {
    'sent' => DeliveryStatus.sent,
    'failed' => DeliveryStatus.failed,
    'pending' => DeliveryStatus.pending,
    _ => null,
  };
  if (email == null || email.isEmpty || status == null) return null;
  final when = DateTime.tryParse(row['sent_at']?.toString() ?? '') ?? DateTime.tryParse(row['created_at']?.toString() ?? '');
  final error = row['error']?.toString();
  return ReportDelivery(email: email, status: status, error: error == null || error.isEmpty ? null : error, at: when?.toLocal());
}

/// The addresses whose LATEST attempt for this report failed. [newestFirst] is the log as the database gives it; the first attempt seen for an address is its latest.
List<String> failedAddresses(List<ReportDelivery> newestFirst) {
  final seen = <String>{};
  final failed = <String>[];
  for (final d in newestFirst) {
    if (!seen.add(d.email)) continue;
    if (d.status == DeliveryStatus.failed) failed.add(d.email);
  }
  return failed;
}

/// What the e-mail function answered: how many addresses got it and how many did not, and each address.
class ReportSendResult {
  const ReportSendResult({required this.sent, required this.failed, required this.results});

  final int sent;
  final int failed;
  final List<({String email, bool ok})> results;

  int get total => sent + failed;
}

ReportSendResult? parseSendResult(dynamic data) {
  if (data is! Map) return null;
  final sent = data['sent'];
  final failed = data['failed'];
  if (sent is! int || failed is! int) return null;
  final results = <({String email, bool ok})>[
    if (data['results'] is List)
      for (final r in data['results'] as List)
        if (r is Map && r['email'] is String) (email: r['email'] as String, ok: r['ok'] == true),
  ];
  return ReportSendResult(sent: sent, failed: failed, results: results);
}

String _people(int n) => n == 1 ? '1 person' : '$n people';

/// What to tell the person after a send.
String sendResultMessage(ReportSendResult r) {
  if (r.failed == 0 && r.sent > 0) return 'Sent to ${_people(r.sent)}.';
  if (r.sent == 0) return 'Nothing was sent: the e-mail was not accepted. Try again in a moment.';
  return 'Sent to ${r.sent} of ${r.total}. ${r.failed} could not be reached: you can send again to them.';
}

final RegExp _email = RegExp(r'^[^\s@<>,;]+@[^\s@<>,;]+\.[^\s@<>,;]+$');

/// Why an address cannot be added, or null when it can. The database checks the same, with the same limits.
String? recipientProblem(String input, List<String> existing) {
  final v = input.trim().toLowerCase();
  if (v.isEmpty) return 'Type an e-mail address.';
  if (v.length > 254 || !_email.hasMatch(v)) return 'Enter one e-mail address, like name@company.com.';
  if (existing.any((e) => e.toLowerCase() == v)) return 'That address is already on the list.';
  if (existing.length >= maxReportRecipients) return 'A list can hold at most $maxReportRecipients addresses. Remove one first.';
  return null;
}

/// A file name the database accepts: letters, numbers, spaces and . _ ( ) - only, ending in .pdf, at most 100 characters. Anything else becomes a dash.
String safeReportFileName(String name) {
  var base = name.trim();
  if (base.toLowerCase().endsWith('.pdf')) base = base.substring(0, base.length - 4);
  base = base.replaceAll(RegExp(r'[^A-Za-z0-9 _.()\-]'), '-').replaceAll(RegExp(r'-{2,}'), '-').replaceAll(RegExp(r'^[-. ]+|[-. ]+$'), '');
  if (base.isEmpty) base = 'report';
  if (base.length > 95) base = base.substring(0, 95).replaceAll(RegExp(r'[-. ]+$'), '');
  return '$base.pdf';
}

/// The owner's and the manager's reports can be e-mailed from the report itself; the organizer's from its Sales page.
bool canEmailClubReports(WorkspaceRole role) => role == WorkspaceRole.owner || role == WorkspaceRole.manager;

/// The business to e-mail a club's report under, or null where this person may not e-mail it (the button is then not shown). The database checks it again.
String? emailOrgIdFor(Workspace workspace) => canEmailClubReports(workspace.role) ? workspace.orgId : null;

String listTitle(ReportKind kind, {String? venueName}) => switch (kind) {
  ReportKind.ownerCombined => 'Combined report',
  ReportKind.venueNight => venueName == null || venueName.isEmpty ? 'Night report' : 'Night report: $venueName',
  ReportKind.organizerSales => 'Event report',
};

String listExplainer(ReportKind kind) => switch (kind) {
  ReportKind.ownerCombined => 'Everyone here gets the combined report for every club when you press E-mail this report. Only owners keep this list.',
  ReportKind.venueNight => 'Everyone here gets this club\'s night report when it is e-mailed. The owner and the manager of the club keep this list.',
  ReportKind.organizerSales =>
    'Everyone here gets an event report when you e-mail it. It never holds more than your Sales page shows, so it never holds what a club has not shared with you.',
};

const String reportEmailNote = 'Nothing is sent on its own. A report is e-mailed only when someone presses E-mail this report.';

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// "31 Oct, 18:05" for the log.
String logMoment(DateTime when) {
  final h = when.hour.toString().padLeft(2, '0');
  final m = when.minute.toString().padLeft(2, '0');
  return '${when.day} ${_months[when.month - 1]}, $h:$m';
}

/// One line of the log: "boss@club.example: sent, 31 Oct, 18:05".
String deliveryLine(ReportDelivery d) {
  final when = d.at == null ? '' : ', ${logMoment(d.at!)}';
  return switch (d.status) {
    DeliveryStatus.sent => '${d.email}: sent$when',
    DeliveryStatus.pending => '${d.email}: sending$when',
    DeliveryStatus.failed => '${d.email}: could not be sent$when',
  };
}
