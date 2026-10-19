import 'package:intl/intl.dart';

import '../../floor/logic/bookings_rules.dart' show formatNight;
import '../../ops/logic/ops_json.dart';
import '../../owner/logic/setup_forms.dart' show formatDollars;
import '../../security/logic/security_rules.dart' show kindLabel;

/// Preparing, closing and reporting a night. What may be closed, by whom, with what excused, and what each role may see of the report are
/// the database's rules. This file reads what it sends, words it, and checks what a person typed before it is sent.

class ChecklistItem {
  const ChecklistItem({required this.key, required this.label, required this.phase, required this.done, this.doneByName, this.doneAt});

  final String key;
  final String label;

  /// 'prepare' or 'close'.
  final String phase;
  final bool done;
  final String? doneByName;
  final DateTime? doneAt;

  bool get isClosing => phase == 'close';
}

ChecklistItem? parseChecklistItem(Map<String, dynamic> r) {
  final key = opsStr(r, 'item_key');
  if (key == null) return null;
  return ChecklistItem(
    key: key,
    label: opsStr(r, 'label') ?? key,
    phase: opsStr(r, 'phase') ?? 'prepare',
    done: opsBool(r, 'done'),
    doneByName: opsStr(r, 'done_by_name'),
    doneAt: opsTime(r, 'done_at'),
  );
}

/// Something still open when a night is closed: a count of things ("3 payments waiting to be checked") or a closing item not ticked.
class NightException {
  const NightException({required this.key, required this.label, required this.count, this.isChecklist = false});

  final String key;
  final String label;
  final int count;
  final bool isChecklist;

  String get sentence => isChecklist ? 'Not ticked: $label' : '$count $label';
}

NightException? _parseException(Object? e) {
  if (e is! Map) return null;
  final m = Map<String, dynamic>.from(e);
  final key = opsStr(m, 'key');
  if (key == null) return null;
  return NightException(key: key, label: opsStr(m, 'label') ?? key, count: opsInt(m, 'count'), isChecklist: m['kind'] == 'checklist');
}

List<NightException> _exceptions(Object? list) => [
      if (list is List)
        for (final e in list)
          if (_parseException(e) != null) _parseException(e)!,
    ];

class CloseStatus {
  const CloseStatus({
    required this.status,
    required this.closed,
    required this.exceptions,
    required this.blockers,
    required this.closeItemsOpen,
    this.closedAt,
    this.closedByName,
    this.exceptionsNote,
    this.reopenedAt,
    this.reopenReason,
  });

  /// 'open', 'closed' or 'reopened'.
  final String status;
  final bool closed;
  final DateTime? closedAt;
  final String? closedByName;

  /// What was still open when the night was closed.
  final List<NightException> exceptions;
  final String? exceptionsNote;
  final DateTime? reopenedAt;
  final String? reopenReason;

  /// What is still open now.
  final List<NightException> blockers;

  /// The closing checklist items not ticked, by name.
  final List<String> closeItemsOpen;

  bool get reopened => status == 'reopened';

  /// Everything that would be an exception if the night were closed now.
  List<NightException> get wouldBeExceptions => [
        ...blockers,
        for (final l in closeItemsOpen) NightException(key: l, label: l, count: 1, isChecklist: true),
      ];
}

CloseStatus? parseCloseStatus(Map<String, dynamic> r) => CloseStatus(
      status: opsStr(r, 'status') ?? 'open',
      closed: opsBool(r, 'closed'),
      closedAt: opsTime(r, 'closed_at'),
      closedByName: opsStr(r, 'closed_by_name'),
      exceptions: _exceptions(r['exceptions']),
      exceptionsNote: opsStr(r, 'exceptions_note'),
      reopenedAt: opsTime(r, 'reopened_at'),
      reopenReason: opsStr(r, 'reopen_reason'),
      blockers: _exceptions(r['blockers']),
      closeItemsOpen: [
        if (r['close_items_open'] is List)
          for (final l in r['close_items_open'] as List) l.toString(),
      ],
    );

/// What a person typed to close with things still open: a reason of at least 10 characters.
String? checkCloseNote(String note) {
  final t = note.trim();
  if (t.length < 10) return 'Say why you are closing with these still open (at least 10 characters).';
  if (t.length > 500) return 'Keep the note to 500 characters or fewer.';
  return null;
}

String? checkReopenReason(String reason) {
  final t = reason.trim();
  if (t.length < 10) return 'Say why this night is being reopened (at least 10 characters).';
  if (t.length > 500) return 'Keep the reason to 500 characters or fewer.';
  return null;
}

// -------------------------------------------------------------------------------------------------------------------------------------
// The report
// -------------------------------------------------------------------------------------------------------------------------------------

class NightReport {
  const NightReport({
    required this.view,
    required this.isFinal,
    required this.venueName,
    required this.night,
    required this.sections,
    this.generatedAt,
    this.closedAt,
    this.closedByName,
    this.exceptions = const [],
    this.exceptionsNote,
  });

  /// 'full' (manager, owner), 'finance' (payment verifier) or 'security'.
  final String view;
  final bool isFinal;
  final String venueName;
  final String night;
  final DateTime? generatedAt;
  final DateTime? closedAt;
  final String? closedByName;
  final List<NightException> exceptions;
  final String? exceptionsNote;

  /// The sections the database gave this role, by name ('bookings', 'payments', 'cash', ...).
  final Map<String, Map<String, dynamic>> sections;

  String get viewLabel => switch (view) {
        'finance' => 'Finance report',
        'security' => 'Security report',
        _ => 'Nightly report',
      };
}

NightReport? parseNightReport(Map<String, dynamic> r) {
  final night = opsStr(r, 'business_night');
  if (night == null) return null;
  const names = ['bookings', 'payments', 'cash', 'flags', 'bottles', 'service', 'security'];
  return NightReport(
    view: opsStr(r, 'view') ?? 'full',
    isFinal: opsBool(r, 'final'),
    venueName: opsStr(r, 'venue_name') ?? 'Club',
    night: night,
    generatedAt: opsTime(r, 'generated_at'),
    closedAt: opsTime(r, 'closed_at'),
    closedByName: opsStr(r, 'closed_by_name'),
    exceptions: _exceptions(r['exceptions']),
    exceptionsNote: opsStr(r, 'exceptions_note'),
    sections: {
      for (final n in names)
        if (r[n] is Map) n: Map<String, dynamic>.from(r[n] as Map),
    },
  );
}

class ReportRow {
  const ReportRow(this.label, this.value, {this.strong = false});

  final String label;
  final String value;
  final bool strong;
}

class ReportSection {
  const ReportSection(this.title, this.rows);

  final String title;
  final List<ReportRow> rows;
}

/// A report as it is shown and printed: the same words on the screen and in the PDF.
class ReportDocument {
  const ReportDocument({required this.title, required this.subtitle, required this.statusLine, required this.sections, required this.fileName});

  final String title;
  final String subtitle;

  /// "FINAL · closed 03:12 by Mia" or "PRELIMINARY · not final until the night is closed".
  final String statusLine;
  final List<ReportSection> sections;
  final String fileName;
}

String _n(Map<String, dynamic>? m, String key) => opsInt(m ?? const {}, key).toString();
String _d(Map<String, dynamic>? m, String key) => formatDollars(opsInt(m ?? const {}, key));

String _time(DateTime? t) => t == null ? '' : DateFormat('HH:mm').format(t.toLocal());

ReportDocument buildReportDocument(NightReport r) {
  final sections = <ReportSection>[];
  final b = r.sections['bookings'];
  final p = r.sections['payments'];
  final c = r.sections['cash'];
  final f = r.sections['flags'];
  final bt = r.sections['bottles'];
  final sv = r.sections['service'];
  final sec = r.sections['security'];

  if (b != null) {
    sections.add(ReportSection('Tables and guests', [
      ReportRow('Tables booked', _n(b, 'count')),
      ReportRow('Guests', _n(b, 'guests')),
      ReportRow('Guests seated (tables)', _n(b, 'seated')),
    ]));
    sections.add(ReportSection('Sales', [
      ReportRow('Booked total', _d(b, 'total_cents'), strong: true),
      ReportRow('Paid so far', _d(b, 'paid_cents')),
      ReportRow('Balance still due', _d(b, 'balance_cents')),
      ReportRow('Discounts', _d(b, 'discount_cents')),
    ]));
  }
  if (p != null) {
    sections.add(ReportSection('Payments recorded at the club', [
      ReportRow('Payments', _n(p, 'count')),
      ReportRow('Collected', _d(p, 'collected_cents'), strong: true),
      ReportRow('Cash', _d(p, 'cash_cents')),
      ReportRow('Debit', _d(p, 'debit_cents')),
      ReportRow('Credit', _d(p, 'credit_cents')),
      ReportRow('Card part of split payments', _d(p, 'split_card_cents')),
      ReportRow('Tax', _d(p, 'tax_cents')),
      ReportRow('Gratuity', _d(p, 'gratuity_cents')),
      ReportRow('Not yet verified', _n(p, 'unverified')),
      ReportRow('Disputed by the guest', _n(p, 'disputed')),
      ReportRow('Without a receipt photo', _n(p, 'no_receipt')),
      ReportRow('Corrections (each counted once)', _n(p, 'corrections')),
    ]));
  }
  if (c != null) {
    sections.add(ReportSection('Cash', [
      ReportRow('Handovers', _n(c, 'handovers')),
      ReportRow('Handed in', _d(c, 'claimed_cents')),
      ReportRow('Counted', _d(c, 'counted_cents'), strong: true),
      ReportRow('Shortages', _d(c, 'shortage_cents')),
      ReportRow('Overages', _d(c, 'overage_cents')),
      ReportRow('Waiting to be counted', _n(c, 'waiting')),
      ReportRow('Still held by staff', _d(c, 'held_cents')),
    ]));
  }
  if (f != null) {
    final by = f['by_resolution'];
    sections.add(ReportSection('Flagged payments', [
      ReportRow('Flagged', _n(f, 'raised')),
      ReportRow('Still open', _n(f, 'open')),
      ReportRow('Resolved', _n(f, 'resolved')),
      if (by is Map)
        for (final e in by.entries) ReportRow('Resolved as ${e.key.toString().replaceAll('_', ' ')}', e.value.toString()),
    ]));
  }
  if (bt != null) {
    sections.add(ReportSection('Bottle orders', [
      ReportRow('Bottles ordered', _n(bt, 'lines')),
      ReportRow('Value', _d(bt, 'value_cents'), strong: true),
      ReportRow('Served', _n(bt, 'served')),
      ReportRow('In progress', _n(bt, 'in_progress')),
      ReportRow('Waiting to be prepared', _n(bt, 'awaiting')),
      ReportRow('Cancelled', _n(bt, 'cancelled')),
      ReportRow('To be paid at the club', _n(bt, 'due_at_venue')),
    ]));
  }
  if (sv != null) {
    sections.add(ReportSection('Requests from tables', [
      ReportRow('Requests', _n(sv, 'total')),
      ReportRow('Completed', _n(sv, 'completed')),
      ReportRow('Escalated', _n(sv, 'escalated')),
      ReportRow('Still open', _n(sv, 'open')),
    ]));
  }
  if (sec != null) {
    final alerts = sec['alerts'] is Map ? Map<String, dynamic>.from(sec['alerts'] as Map) : <String, dynamic>{};
    final tasks = sec['tasks'] is Map ? Map<String, dynamic>.from(sec['tasks'] as Map) : <String, dynamic>{};
    final kinds = alerts['by_kind'];
    final incidents = sec['incidents'] is List ? sec['incidents'] as List : const [];
    sections.add(ReportSection('Security', [
      ReportRow('Alerts', _n(alerts, 'total')),
      ReportRow('Urgent', _n(alerts, 'urgent')),
      ReportRow('Escalated', _n(alerts, 'escalated')),
      ReportRow('Not resolved', _n(alerts, 'unresolved')),
      if (kinds is Map) for (final e in kinds.entries) ReportRow('  ${kindLabel(e.key.toString())}', e.value.toString()),
      ReportRow('Tasks', _n(tasks, 'total')),
      ReportRow('Tasks done', _n(tasks, 'done')),
      ReportRow('Incident reports', incidents.length.toString()),
      for (final i in incidents)
        if (i is Map) ReportRow('  ${kindLabel(i['kind']?.toString() ?? 'other')} · ${i['location'] ?? ''}', i['status'] == 'reviewed' ? 'Reviewed' : 'Not reviewed'),
    ]));
  }
  if (r.isFinal && r.exceptions.isNotEmpty) {
    sections.add(ReportSection('Closed with exceptions', [
      for (final e in r.exceptions) ReportRow(e.isChecklist ? 'Not ticked' : e.label, e.isChecklist ? e.label : e.count.toString()),
      if (r.exceptionsNote != null) ReportRow('Reason given', r.exceptionsNote!),
    ]));
  }

  final status = r.isFinal
      ? 'FINAL · closed${r.closedAt == null ? '' : ' ${_time(r.closedAt)}'}${r.closedByName == null ? '' : ' by ${r.closedByName}'}'
      : 'PRELIMINARY · figures as of ${_time(r.generatedAt)}; not final until the night is closed';
  final slug = r.venueName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
  return ReportDocument(
    title: r.viewLabel,
    subtitle: '${r.venueName} · ${formatNight(r.night)}',
    statusLine: status,
    sections: sections,
    fileName: '${slug.isEmpty ? 'club' : slug}-${r.night}-${r.view}-${r.isFinal ? 'final' : 'preliminary'}.pdf',
  );
}
