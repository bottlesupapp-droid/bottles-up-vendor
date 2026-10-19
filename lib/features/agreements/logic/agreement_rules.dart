import 'package:intl/intl.dart';

import '../../ops/logic/ops_json.dart';
import '../../owner/logic/setup_forms.dart' show formatDollars;

/// Venue agreements for an event. Who may ask, propose, accept or close, that the two acceptances come from two different people, and that
/// only the latest version can be accepted are the database's rules. This file reads what it sends, words it, works out the sample, and
/// checks what a person typed before it is sent.

class AgreementRow {
  const AgreementRow({
    required this.id,
    required this.eventTitle,
    required this.venueName,
    required this.organizerName,
    required this.status,
    required this.currentVersion,
    required this.side,
    this.eventStart,
    this.activeVersion,
    this.waitingOn,
    this.closedReason,
  });

  final String id;
  final String eventTitle;
  final DateTime? eventStart;
  final String venueName;
  final String organizerName;

  /// 'requested', 'negotiating', 'active', 'changes_pending', 'declined' or 'cancelled'.
  final String status;
  final int currentVersion;
  final int? activeVersion;

  /// Which side this list is for: 'venue' or 'organizer'.
  final String side;

  /// 'venue', 'organizer', or null when nobody has to act.
  final String? waitingOn;
  final String? closedReason;

  bool get closed => status == 'declined' || status == 'cancelled';
  bool get waitingOnMe => waitingOn != null && waitingOn == side;
}

AgreementRow? parseAgreementRow(Map<String, dynamic> r) {
  final id = opsStr(r, 'agreement_id');
  if (id == null) return null;
  return AgreementRow(
    id: id,
    eventTitle: opsStr(r, 'event_title') ?? 'Event',
    eventStart: opsTime(r, 'event_start'),
    venueName: opsStr(r, 'venue_name') ?? 'Club',
    organizerName: opsStr(r, 'organizer_name') ?? 'Organizer',
    status: opsStr(r, 'status') ?? 'requested',
    currentVersion: opsInt(r, 'current_version'),
    activeVersion: r['active_version'] == null ? null : opsInt(r, 'active_version'),
    side: opsStr(r, 'side') ?? 'venue',
    waitingOn: opsStr(r, 'waiting_on'),
    closedReason: opsStr(r, 'closed_reason'),
  );
}

String agreementStatusLabel(String status) => switch (status) {
      'requested' => 'Requested',
      'negotiating' => 'Being agreed',
      'active' => 'Active',
      'changes_pending' => 'Active, change proposed',
      'declined' => 'Declined',
      'cancelled' => 'Cancelled',
      _ => status,
    };

/// Who has to do something next, from the point of view of [side].
String waitingLine(AgreementRow a) {
  if (a.closed) return a.closedReason == null ? agreementStatusLabel(a.status) : '${agreementStatusLabel(a.status)}: ${a.closedReason}';
  final w = a.waitingOn;
  if (w == null) return a.status == 'active' ? 'Agreed. Nothing waiting.' : 'Nothing waiting.';
  if (w == a.side) return a.currentVersion == 0 ? 'Waiting for you to review the request' : 'Waiting for you to review version ${a.currentVersion}';
  final other = w == 'venue' ? 'the club' : 'the organizer';
  return a.currentVersion == 0 ? 'Waiting for $other to respond' : 'Waiting for $other to accept version ${a.currentVersion}';
}

class AgreementVersion {
  const AgreementVersion({
    required this.version,
    required this.terms,
    required this.proposedBySide,
    required this.isActive,
    this.note,
    this.proposedByName,
    this.proposedAt,
    this.organizerAcceptedByName,
    this.organizerAcceptedAt,
    this.venueAcceptedByName,
    this.venueAcceptedAt,
  });

  final int version;
  final Map<String, dynamic> terms;
  final String? note;
  final String proposedBySide;
  final String? proposedByName;
  final DateTime? proposedAt;
  final String? organizerAcceptedByName;
  final DateTime? organizerAcceptedAt;
  final String? venueAcceptedByName;
  final DateTime? venueAcceptedAt;
  final bool isActive;

  bool get organizerAccepted => organizerAcceptedAt != null;
  bool get venueAccepted => venueAcceptedAt != null;
  bool get bothAccepted => organizerAccepted && venueAccepted;
}

class AgreementNote {
  const AgreementNote({required this.side, required this.body, required this.authorName, required this.isMine, this.version, this.createdAt});

  final String side;
  final int? version;
  final String body;
  final String authorName;
  final bool isMine;
  final DateTime? createdAt;
}

class AgreementDetail {
  const AgreementDetail({
    required this.id,
    required this.status,
    required this.side,
    required this.eventTitle,
    required this.venueName,
    required this.organizerName,
    required this.currentVersion,
    required this.canAccept,
    required this.canPropose,
    required this.canClose,
    required this.versions,
    required this.notes,
    this.eventStart,
    this.activeVersion,
    this.requestNote,
    this.closedReason,
  });

  final String id;
  final String status;

  /// The side the viewer is on: 'organizer' or 'venue'.
  final String side;
  final String eventTitle;
  final DateTime? eventStart;
  final String venueName;
  final String organizerName;
  final int currentVersion;
  final int? activeVersion;
  final String? requestNote;
  final String? closedReason;
  final bool canAccept;
  final bool canPropose;
  final bool canClose;

  /// Newest first.
  final List<AgreementVersion> versions;
  final List<AgreementNote> notes;

  bool get closed => status == 'declined' || status == 'cancelled';
  AgreementVersion? get latest => versions.isEmpty ? null : versions.first;
  AgreementVersion? get previous => versions.length < 2 ? null : versions[1];
  AgreementVersion? get active => versions.where((v) => v.isActive).firstOrNull;
}

AgreementDetail? parseAgreementDetail(Map<String, dynamic> r) {
  final id = opsStr(r, 'agreement_id');
  if (id == null) return null;
  final versions = r['versions'];
  final notes = r['notes'];
  return AgreementDetail(
    id: id,
    status: opsStr(r, 'status') ?? 'requested',
    side: opsStr(r, 'side') ?? 'venue',
    eventTitle: opsStr(r, 'event_title') ?? 'Event',
    eventStart: opsTime(r, 'event_start'),
    venueName: opsStr(r, 'venue_name') ?? 'Club',
    organizerName: opsStr(r, 'organizer_name') ?? 'Organizer',
    currentVersion: opsInt(r, 'current_version'),
    activeVersion: r['active_version'] == null ? null : opsInt(r, 'active_version'),
    requestNote: opsStr(r, 'request_note'),
    closedReason: opsStr(r, 'closed_reason'),
    canAccept: opsBool(r, 'can_accept'),
    canPropose: opsBool(r, 'can_propose'),
    canClose: opsBool(r, 'can_close'),
    versions: [
      if (versions is List)
        for (final v in versions)
          if (v is Map)
            AgreementVersion(
              version: opsInt(Map<String, dynamic>.from(v), 'version'),
              terms: v['terms'] is Map ? Map<String, dynamic>.from(v['terms'] as Map) : const {},
              note: opsStr(Map<String, dynamic>.from(v), 'note'),
              proposedBySide: v['proposed_by_side']?.toString() ?? 'venue',
              proposedByName: opsStr(Map<String, dynamic>.from(v), 'proposed_by_name'),
              proposedAt: opsTime(Map<String, dynamic>.from(v), 'proposed_at'),
              organizerAcceptedByName: opsStr(Map<String, dynamic>.from(v), 'organizer_accepted_by_name'),
              organizerAcceptedAt: opsTime(Map<String, dynamic>.from(v), 'organizer_accepted_at'),
              venueAcceptedByName: opsStr(Map<String, dynamic>.from(v), 'venue_accepted_by_name'),
              venueAcceptedAt: opsTime(Map<String, dynamic>.from(v), 'venue_accepted_at'),
              isActive: v['is_active'] == true,
            ),
    ],
    notes: [
      if (notes is List)
        for (final n in notes)
          if (n is Map)
            AgreementNote(
              side: n['side']?.toString() ?? 'venue',
              version: n['version'] == null ? null : opsInt(Map<String, dynamic>.from(n), 'version'),
              body: n['body']?.toString() ?? '',
              authorName: opsStr(Map<String, dynamic>.from(n), 'author_name') ?? 'Staff member',
              isMine: n['is_mine'] == true,
              createdAt: opsTime(Map<String, dynamic>.from(n), 'created_at'),
            ),
    ],
  );
}

// -------------------------------------------------------------------------------------------------------------------------------------
// The terms
// -------------------------------------------------------------------------------------------------------------------------------------

/// One term as the form and the review show it: the key the database uses, the words for a person, and how it is typed.
class TermSpec {
  const TermSpec(this.key, this.label, {this.hint, this.kind = TermKind.text});

  final String key;
  final String label;
  final String? hint;
  final TermKind kind;
}

enum TermKind { text, longText, time, count, percent, money, choice }

const List<TermSpec> termSpecs = [
  TermSpec('starts', 'Doors open', hint: 'For example 21:00', kind: TermKind.time),
  TermSpec('ends', 'Ends', hint: 'For example 03:00', kind: TermKind.time),
  TermSpec('rooms', 'Rooms'),
  TermSpec('capacity', 'Capacity', kind: TermKind.count),
  TermSpec('ticket_ownership', 'Who owns the ticket sales', kind: TermKind.choice),
  TermSpec('table_allocation', 'Table payments: who receives what'),
  TermSpec('bar_percent', 'Organizer\'s share of bar sales (%)', kind: TermKind.percent),
  TermSpec('threshold_cents', 'Threshold', hint: 'Bar sales needed before the share applies (0 if from the first sale)', kind: TermKind.money),
  TermSpec('formula', 'How the share is worked out', kind: TermKind.choice),
  TermSpec('eligible_revenue', 'Which revenue counts', hint: 'For example bar sales after tax'),
  TermSpec('refunds', 'Refunds'),
  TermSpec('discounts', 'Discounts'),
  TermSpec('complimentary_items', 'Complimentary items'),
  TermSpec('taxes_tips_fees', 'Taxes, tips and fees'),
  TermSpec('min_spend_rules', 'Minimum spend'),
  TermSpec('admissions', 'Admissions'),
  TermSpec('complimentary_allowance', 'Complimentary allowance (how many)', kind: TermKind.count),
  TermSpec('responsibilities', 'Who is responsible for what', kind: TermKind.longText),
  TermSpec('cancellation', 'If the event is cancelled'),
  TermSpec('settlement_timing', 'When the settlement is done'),
];

const Map<String, String> ticketOwnershipLabels = {'organizer': 'The organizer', 'venue': 'The club', 'shared': 'Shared'};
const Map<String, String> formulaLabels = {
  'above_threshold': 'A percentage of sales ABOVE the threshold',
  'all_once_reached': 'A percentage of ALL sales once the threshold is reached',
};

/// A stored value in words: money as dollars, a percentage with its sign, a choice by its name.
String termValueLabel(String key, Object? value) {
  switch (key) {
    case 'threshold_cents':
      return formatDollars(value is num ? value.toInt() : int.tryParse('$value') ?? 0);
    case 'bar_percent':
      final n = value is num ? value : num.tryParse('$value') ?? 0;
      return '${n == n.roundToDouble() ? n.toInt() : n}%';
    case 'ticket_ownership':
      return ticketOwnershipLabels['$value'] ?? '$value';
    case 'formula':
      return formulaLabels['$value'] ?? '$value';
    default:
      return '$value';
  }
}

/// The terms of a version as label and value, in the order the form has them. Terms that were not given are left out.
List<({String key, String label, String value})> termsLines(Map<String, dynamic> terms) => [
      for (final s in termSpecs)
        if (terms[s.key] != null) (key: s.key, label: s.label, value: termValueLabel(s.key, terms[s.key])),
    ];

/// What differs between two versions of the terms, as a sentence per term: "Capacity: 400 → 350", "Added: Rooms", "Removed: Admissions".
List<String> termsChanges(Map<String, dynamic> from, Map<String, dynamic> to) {
  final out = <String>[];
  for (final s in termSpecs) {
    final a = from[s.key];
    final b = to[s.key];
    if (a == b) continue;
    if (a == null) {
      out.add('Added: ${s.label} = ${termValueLabel(s.key, b)}');
    } else if (b == null) {
      out.add('Removed: ${s.label}');
    } else {
      out.add('${s.label}: ${termValueLabel(s.key, a)} → ${termValueLabel(s.key, b)}');
    }
  }
  return out;
}

/// What the organizer's share comes to, in cents, on [salesCents] of eligible bar sales: the database's rule, so the number shown before
/// anyone accepts is the one the agreement means. A percentage of sales ABOVE the threshold and of ALL sales once it is reached differ.
int sampleShareCents(Map<String, dynamic> terms, int salesCents) {
  if (salesCents < 0) return 0;
  final pct = terms['bar_percent'] is num ? (terms['bar_percent'] as num).toDouble() : 0.0;
  if (pct == 0) return 0;
  final threshold = terms['threshold_cents'] is num ? (terms['threshold_cents'] as num).toInt() : 0;
  switch (terms['formula']) {
    case 'above_threshold':
      final base = salesCents > threshold ? salesCents - threshold : 0;
      return (base * pct / 100).roundToDouble().toInt();
    case 'all_once_reached':
      return salesCents >= threshold ? (salesCents * pct / 100).roundToDouble().toInt() : 0;
    default:
      return 0;
  }
}

/// A sentence for the sample: "On $8,000.00 of bar sales the organizer's share would be $300.00."
String? sampleSentence(Map<String, dynamic> terms, int salesCents) {
  if (terms['bar_percent'] is! num || (terms['bar_percent'] as num) == 0) return null;
  return 'On ${formatDollars(salesCents)} of bar sales the organizer\'s share would be ${formatDollars(sampleShareCents(terms, salesCents))}.';
}

// -------------------------------------------------------------------------------------------------------------------------------------
// What was typed
// -------------------------------------------------------------------------------------------------------------------------------------

final RegExp _time = RegExp(r'^([01][0-9]|2[0-3]):[0-5][0-9]$');

/// The form's values, as typed, turned into the terms to send, or the first thing that is wrong (mirroring what the database requires).
({Map<String, dynamic>? terms, String? error}) buildTerms(Map<String, String> typed) {
  final terms = <String, dynamic>{};
  for (final s in termSpecs) {
    final raw = (typed[s.key] ?? '').trim();
    if (raw.isEmpty) continue;
    switch (s.kind) {
      case TermKind.time:
        if (!_time.hasMatch(raw)) return (terms: null, error: '${s.label} must be a time like 21:00.');
        terms[s.key] = raw;
      case TermKind.count:
        final n = int.tryParse(raw);
        if (n == null || n < (s.key == 'capacity' ? 1 : 0)) return (terms: null, error: '${s.label} must be a whole number${s.key == 'capacity' ? ' from 1' : ''}.');
        terms[s.key] = n;
      case TermKind.percent:
        final n = double.tryParse(raw);
        if (n == null || n < 0 || n > 100) return (terms: null, error: 'The share must be a number from 0 to 100.');
        if ((n * 100).roundToDouble() != n * 100) return (terms: null, error: 'The share can have at most two decimals.');
        terms[s.key] = n == n.roundToDouble() ? n.toInt() : n;
      case TermKind.money:
        final cents = parseMoneyToCents(raw);
        if (cents == null) return (terms: null, error: '${s.label} must be an amount like 5000 or 5000.00.');
        terms[s.key] = cents;
      case TermKind.choice:
        terms[s.key] = raw;
      case TermKind.text:
        if (raw.length > 300) return (terms: null, error: '${s.label}: keep it to 300 characters or fewer.');
        terms[s.key] = raw;
      case TermKind.longText:
        if (raw.length > 500) return (terms: null, error: '${s.label}: keep it to 500 characters or fewer.');
        terms[s.key] = raw;
    }
  }
  if (terms.isEmpty) return (terms: null, error: 'Fill in at least one term.');
  final pct = terms['bar_percent'];
  if (pct is num && pct > 0) {
    if (terms['threshold_cents'] == null) return (terms: null, error: 'A share of bar sales needs a threshold (0 if it applies from the first sale).');
    if (terms['formula'] == null) return (terms: null, error: 'Say whether the share is of sales ABOVE the threshold or of ALL sales once it is reached.');
    if (terms['eligible_revenue'] == null) return (terms: null, error: 'Say which revenue counts towards the share.');
    if (terms['refunds'] == null) return (terms: null, error: 'Say how refunds are treated.');
    if (terms['taxes_tips_fees'] == null) return (terms: null, error: 'Say how taxes, tips and fees are treated.');
  }
  return (terms: terms, error: null);
}

/// "5000", "5,000.50" or "$5000" as cents, or null.
int? parseMoneyToCents(String text) {
  final t = text.trim().replaceAll(r'$', '').replaceAll(',', '');
  final m = RegExp(r'^(\d{1,9})(?:\.(\d{1,2}))?$').firstMatch(t);
  if (m == null) return null;
  final dollars = int.parse(m.group(1)!);
  final cents = m.group(2) == null ? 0 : int.parse(m.group(2)!.padRight(2, '0'));
  return dollars * 100 + cents;
}

String? checkAgreementNote(String text) {
  final t = text.trim();
  if (t.isEmpty) return 'Write the note first.';
  if (t.length > 1000) return 'Keep a note to 1000 characters or fewer.';
  return null;
}

String? checkCloseReason(String text) {
  final t = text.trim();
  if (t.length < 3) return 'Say why.';
  if (t.length > 500) return 'Keep the reason to 500 characters or fewer.';
  return null;
}

String? checkRequestMessage(String text) => text.trim().length > 500 ? 'Keep the message to 500 characters or fewer.' : null;

String agreementTime(DateTime? at) => at == null ? '' : DateFormat('d MMM HH:mm').format(at.toLocal());
