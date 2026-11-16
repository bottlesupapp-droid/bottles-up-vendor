import 'package:intl/intl.dart';

import '../../agreements/logic/agreement_rules.dart' show parseMoneyToCents;
import '../../ops/logic/ops_json.dart';

// Organizer settlement RECORDS (website 20261122120000_organizer_settlements.sql; brief section 25). Record only: what a club owes an organizer for their share of bar sales under the
// accepted agreement, and the payment once it was made somewhere else. Nothing here pays anyone. The database counts, decides who may do what (the detail says it, in `can`) and keeps the
// history; this file reads what it sends, words it, and checks what was typed before it is sent.

/// The money in words: "$300.00 CAD", a minus sign for a negative one. Whole cents, no floating point.
String settlementMoney(int cents, {String currency = 'cad'}) {
  final abs = cents.abs();
  final dollars = NumberFormat('#,##0').format(abs ~/ 100);
  final rest = (abs % 100).toString().padLeft(2, '0');
  return '${cents < 0 ? '−' : ''}\$$dollars.$rest ${currency.toUpperCase()}';
}

enum SettlementTone { neutral, attention, good, bad }

class SettlementStatusInfo {
  const SettlementStatusInfo(this.label, this.note, this.tone);

  final String label;
  final String note;
  final SettlementTone tone;
}

/// What a status says. "Reconciliation pending" and "Payment pending" (the brief's words) are the waiting between steps, so they are the notes under Estimated and Approved.
SettlementStatusInfo settlementStatusInfo(String? status) => switch (status) {
  null => const SettlementStatusInfo('Not started', 'Waiting for the club to enter the bar sales', SettlementTone.neutral),
  'estimated' => const SettlementStatusInfo('Estimated', 'Reconciliation pending', SettlementTone.attention),
  'reviewed' => const SettlementStatusInfo('Reviewed', 'Waiting for the owner to approve it', SettlementTone.attention),
  'approved' => const SettlementStatusInfo('Approved', 'Payment pending', SettlementTone.attention),
  'paid' => const SettlementStatusInfo('Paid', 'Recorded external payment', SettlementTone.good),
  'disputed' => const SettlementStatusInfo('Disputed', 'The organizer has asked a question', SettlementTone.bad),
  _ => const SettlementStatusInfo('Unknown', '', SettlementTone.neutral),
};

num? _num(Map<String, dynamic> r, String key) {
  final v = r[key];
  if (v is num) return v;
  return num.tryParse('${v ?? ''}');
}

int? _intOrNull(Map<String, dynamic> r, String key) => _num(r, key)?.round();

String _percent(num p) => p % 1 == 0 ? '${p.toInt()}' : '$p';

/// What the agreement says about the share, in one sentence: "10% of the sales above $5,000.00".
String shareSummary({required num? percent, required int? thresholdCents, required String? formula}) {
  if (percent == null || percent <= 0) return 'No share of bar sales';
  final threshold = settlementMoney(thresholdCents ?? 0).replaceAll(' CAD', '');
  return switch (formula) {
    'above_threshold' => '${_percent(percent)}% of the sales above $threshold',
    'all_once_reached' => '${_percent(percent)}% of all the sales once $threshold is reached',
    _ => '${_percent(percent)}% of bar sales',
  };
}

/// A row of the list: one agreement that has a share of bar sales to settle, with its settlement if there is one.
class SettlementRow {
  const SettlementRow({
    required this.agreementId,
    required this.eventTitle,
    required this.venueName,
    required this.organizerName,
    this.eventStart,
    this.barPercent,
    this.thresholdCents,
    this.formula,
    this.settlementId,
    this.status,
    this.payableCents,
    this.paidOn,
    this.updatedAt,
  });

  final String agreementId;
  final String eventTitle;
  final String venueName;
  final String organizerName;
  final DateTime? eventStart;
  final num? barPercent;
  final int? thresholdCents;
  final String? formula;
  final String? settlementId;
  final String? status;
  final int? payableCents;
  final DateTime? paidOn;
  final DateTime? updatedAt;

  bool get started => settlementId != null;

  String get terms => shareSummary(percent: barPercent, thresholdCents: thresholdCents, formula: formula);
}

SettlementRow? parseSettlementRow(Map<String, dynamic> r) {
  final id = opsStr(r, 'agreement_id');
  if (id == null) return null;
  return SettlementRow(
    agreementId: id,
    eventTitle: opsStr(r, 'event_title') ?? 'Event',
    venueName: opsStr(r, 'venue_name') ?? 'Club',
    organizerName: opsStr(r, 'organizer_name') ?? 'Organizer',
    eventStart: opsTime(r, 'event_start'),
    barPercent: _num(r, 'bar_percent'),
    thresholdCents: _intOrNull(r, 'threshold_cents'),
    formula: opsStr(r, 'formula'),
    settlementId: opsStr(r, 'settlement_id'),
    status: opsStr(r, 'status'),
    payableCents: _intOrNull(r, 'payable_cents'),
    paidOn: opsTime(r, 'paid_on'),
    updatedAt: opsTime(r, 'updated_at'),
  );
}

/// The agreed terms that matter to a settlement, as the settlement was worked out with them.
class SettlementTerms {
  const SettlementTerms({this.barPercent, this.thresholdCents, this.formula, this.eligibleRevenue, this.refunds, this.taxesTipsFees, this.settlementTiming});

  final num? barPercent;
  final int? thresholdCents;
  final String? formula;
  final String? eligibleRevenue;
  final String? refunds;
  final String? taxesTipsFees;
  final String? settlementTiming;

  String get summary => shareSummary(percent: barPercent, thresholdCents: thresholdCents, formula: formula);
}

SettlementTerms? _parseTerms(Object? v) {
  if (v is! Map) return null;
  final m = Map<String, dynamic>.from(v);
  return SettlementTerms(
    barPercent: _num(m, 'bar_percent'),
    thresholdCents: _intOrNull(m, 'threshold_cents'),
    formula: opsStr(m, 'formula'),
    eligibleRevenue: opsStr(m, 'eligible_revenue'),
    refunds: opsStr(m, 'refunds'),
    taxesTipsFees: opsStr(m, 'taxes_tips_fees'),
    settlementTiming: opsStr(m, 'settlement_timing'),
  );
}

/// The settlement itself. Every figure is the database's; [payableCents] is the share plus the adjustment.
class SettlementRecord {
  const SettlementRecord({
    required this.id,
    required this.status,
    required this.currency,
    required this.eligibleSalesCents,
    required this.salesNote,
    required this.baseCents,
    required this.shareCents,
    required this.adjustmentCents,
    required this.payableCents,
    this.adjustmentNote,
    this.enteredByName,
    this.enteredAt,
    this.reviewedByName,
    this.reviewedAt,
    this.approvedByName,
    this.approvedAt,
    this.paidAmountCents,
    this.paidOn,
    this.paymentReference,
    this.paymentEvidence,
    this.paidRecordedByName,
    this.paidRecordedAt,
    this.paymentLabel,
    this.disputedReason,
    this.disputedAt,
    this.acknowledgedByName,
    this.acknowledgedAt,
  });

  final String id;
  final String status;
  final String currency;
  final int eligibleSalesCents;
  final String salesNote;
  final int baseCents;
  final int shareCents;
  final int adjustmentCents;
  final String? adjustmentNote;
  final int payableCents;
  final String? enteredByName;
  final DateTime? enteredAt;
  final String? reviewedByName;
  final DateTime? reviewedAt;
  final String? approvedByName;
  final DateTime? approvedAt;
  final int? paidAmountCents;
  final DateTime? paidOn;
  final String? paymentReference;
  final String? paymentEvidence;
  final String? paidRecordedByName;
  final DateTime? paidRecordedAt;
  final String? paymentLabel;
  final String? disputedReason;
  final DateTime? disputedAt;
  final String? acknowledgedByName;
  final DateTime? acknowledgedAt;

  bool get isPaid => status == 'paid';
}

SettlementRecord? _parseRecord(Object? v) {
  if (v is! Map) return null;
  final m = Map<String, dynamic>.from(v);
  final id = opsStr(m, 'id');
  final status = opsStr(m, 'status');
  if (id == null || status == null) return null;
  return SettlementRecord(
    id: id,
    status: status,
    currency: opsStr(m, 'currency') ?? 'cad',
    eligibleSalesCents: opsInt(m, 'eligible_sales_cents'),
    salesNote: opsStr(m, 'sales_note') ?? '',
    baseCents: opsInt(m, 'base_cents'),
    shareCents: opsInt(m, 'share_cents'),
    adjustmentCents: opsInt(m, 'adjustment_cents'),
    adjustmentNote: opsStr(m, 'adjustment_note'),
    payableCents: opsInt(m, 'payable_cents'),
    enteredByName: opsStr(m, 'entered_by_name'),
    enteredAt: opsTime(m, 'entered_at'),
    reviewedByName: opsStr(m, 'reviewed_by_name'),
    reviewedAt: opsTime(m, 'reviewed_at'),
    approvedByName: opsStr(m, 'approved_by_name'),
    approvedAt: opsTime(m, 'approved_at'),
    paidAmountCents: _intOrNull(m, 'paid_amount_cents'),
    paidOn: opsTime(m, 'paid_on'),
    paymentReference: opsStr(m, 'payment_reference'),
    paymentEvidence: opsStr(m, 'payment_evidence'),
    paidRecordedByName: opsStr(m, 'paid_recorded_by_name'),
    paidRecordedAt: opsTime(m, 'paid_recorded_at'),
    paymentLabel: opsStr(m, 'payment_label'),
    disputedReason: opsStr(m, 'disputed_reason'),
    disputedAt: opsTime(m, 'disputed_at'),
    acknowledgedByName: opsStr(m, 'organizer_ack_by_name'),
    acknowledgedAt: opsTime(m, 'organizer_ack_at'),
  );
}

/// What the person may do, as the database says it (the app never works it out from the role or the status).
class SettlementCan {
  const SettlementCan({
    this.saveSales = false,
    this.adjust = false,
    this.review = false,
    this.approve = false,
    this.recordPayment = false,
    this.acknowledge = false,
    this.question = false,
    this.resolve = false,
  });

  final bool saveSales;
  final bool adjust;
  final bool review;
  final bool approve;
  final bool recordPayment;
  final bool acknowledge;
  final bool question;
  final bool resolve;

  bool get any => saveSales || adjust || review || approve || recordPayment || acknowledge || question || resolve;
}

SettlementCan _parseCan(Object? v) {
  if (v is! Map) return const SettlementCan();
  bool b(String k) => v[k] == true;
  return SettlementCan(
    saveSales: b('save_sales'),
    adjust: b('adjust'),
    review: b('review'),
    approve: b('approve'),
    recordPayment: b('record_payment'),
    acknowledge: b('acknowledge'),
    question: b('question'),
    resolve: b('resolve'),
  );
}

/// One line of the history.
class SettlementLogEntry {
  const SettlementLogEntry({required this.at, required this.side, required this.action, required this.byName, required this.byMe, this.fromStatus, this.toStatus, this.amountCents, this.note});

  final DateTime? at;
  final String side;
  final String action;
  final String? fromStatus;
  final String? toStatus;
  final int? amountCents;
  final String? note;
  final String byName;
  final bool byMe;
}

SettlementLogEntry? _parseLog(Object? v) {
  if (v is! Map) return null;
  final m = Map<String, dynamic>.from(v);
  final action = opsStr(m, 'action');
  if (action == null) return null;
  return SettlementLogEntry(
    at: opsTime(m, 'at'),
    side: opsStr(m, 'side') ?? 'venue',
    action: action,
    fromStatus: opsStr(m, 'from_status'),
    toStatus: opsStr(m, 'to_status'),
    amountCents: _intOrNull(m, 'amount_cents'),
    note: opsStr(m, 'note'),
    byName: opsStr(m, 'by_name') ?? 'Someone',
    byMe: opsBool(m, 'by_me'),
  );
}

/// What a history line says: who took the step (the club or the organizer) and what it was.
String logLine(SettlementLogEntry e, {String currency = 'cad'}) {
  String money(int? c, {bool signed = false}) => c == null ? '' : ' ${signed && c > 0 ? '+' : ''}${settlementMoney(c, currency: currency)}';
  final what = switch (e.action) {
    'sales_saved' => 'Eligible bar sales entered${money(e.amountCents)}',
    'adjusted' => 'Amount adjusted${money(e.amountCents, signed: true)}',
    'reviewed' => 'Reviewed${money(e.amountCents)}',
    'approved' => 'Approved${money(e.amountCents)}',
    'payment_recorded' => 'Payment recorded${money(e.amountCents)}',
    'questioned' => 'Question asked',
    'resolved' => 'Question answered',
    'acknowledged' => 'Acknowledged${money(e.amountCents)}',
    _ => e.action,
  };
  return '$what · ${e.side == 'organizer' ? 'Organizer' : 'Club'}';
}

/// One settlement as the detail page shows it.
class SettlementDetail {
  const SettlementDetail({
    required this.agreementId,
    required this.side,
    required this.eventTitle,
    required this.venueName,
    required this.organizerName,
    required this.agreementStatus,
    required this.hasShare,
    required this.log,
    required this.can,
    this.eventStart,
    this.agreementVersion,
    this.terms,
    this.settlement,
  });

  final String agreementId;

  /// 'venue' (the club's manager or owner) or 'organizer'.
  final String side;
  final String eventTitle;
  final DateTime? eventStart;
  final String venueName;
  final String organizerName;
  final String agreementStatus;
  final int? agreementVersion;
  final SettlementTerms? terms;
  final bool hasShare;
  final SettlementRecord? settlement;
  final List<SettlementLogEntry> log;
  final SettlementCan can;

  String? get status => settlement?.status;

  /// The agreement has ended (declined or cancelled); a settlement that exists can still be completed, but its sales are fixed.
  bool get agreementEnded => agreementStatus == 'declined' || agreementStatus == 'cancelled';
}

SettlementDetail? parseSettlementDetail(Map<String, dynamic> r) {
  final id = opsStr(r, 'agreement_id');
  if (id == null) return null;
  return SettlementDetail(
    agreementId: id,
    side: opsStr(r, 'side') ?? 'venue',
    eventTitle: opsStr(r, 'event_title') ?? 'Event',
    eventStart: opsTime(r, 'event_start'),
    venueName: opsStr(r, 'venue_name') ?? 'Club',
    organizerName: opsStr(r, 'organizer_name') ?? 'Organizer',
    agreementStatus: opsStr(r, 'agreement_status') ?? '',
    agreementVersion: _intOrNull(r, 'agreement_version'),
    terms: _parseTerms(r['terms']),
    hasShare: opsBool(r, 'has_share'),
    settlement: _parseRecord(r['settlement']),
    log:
        [
          if (r['log'] is List)
            for (final e in r['log'] as List) _parseLog(e),
        ].whereType<SettlementLogEntry>().toList(),
    can: _parseCan(r['can']),
  );
}

/// The calculation, line by line, for the page: what the club reported, what the agreement says, what the share comes to, and what is owed.
List<({String label, String value, bool strong})> calculationLines(SettlementTerms? terms, SettlementRecord s) {
  final currency = s.currency;
  String m(int c) => settlementMoney(c, currency: currency);
  return [
    (label: 'Venue-reported eligible bar sales', value: m(s.eligibleSalesCents), strong: false),
    if (terms != null) (label: 'Agreed share', value: terms.summary, strong: false),
    (label: 'Sales the share is worked on', value: m(s.baseCents), strong: false),
    (label: "Organizer's share", value: m(s.shareCents), strong: false),
    if (s.adjustmentCents != 0) (label: 'Adjustments', value: '${s.adjustmentCents > 0 ? '+' : ''}${m(s.adjustmentCents)}', strong: false),
    (label: 'Amount owed to the organizer', value: m(s.payableCents), strong: true),
  ];
}

// ---------------------------------------------------------------------------
// What was typed, checked the way the database will check it
// ---------------------------------------------------------------------------

({int? cents, String? error}) _money(String text, {required String what}) {
  if (text.trim().isEmpty) return (cents: null, error: 'Enter $what.');
  final cents = parseMoneyToCents(text);
  if (cents == null) return (cents: null, error: 'Enter an amount like 8000 or 8,000.50.');
  return (cents: cents, error: null);
}

String? _note(String text, {required int min, required int max, required String what}) {
  final t = text.trim();
  if (t.length < min) return what;
  if (t.length > max) return 'Keep it to $max characters or fewer.';
  return null;
}

/// The eligible bar sales and where they come from.
({int? cents, String? note, String? error}) checkSalesForm(String amount, String source) {
  final m = _money(amount, what: 'the eligible bar sales, for example 8,000.00');
  if (m.error != null) return (cents: null, note: null, error: m.error);
  final problem = _note(source, min: 3, max: 300, what: 'Say where the figure comes from (at least 3 characters).');
  if (problem != null) return (cents: null, note: null, error: problem);
  return (cents: m.cents, note: source.trim(), error: null);
}

/// A plus or minus change to the amount owed, with the reason. [payableCents] is what is owed now: it never goes below 0.
({int? cents, String? note, String? error}) checkAdjustmentForm(String amount, String reason, {required int payableCents}) {
  var t = amount.trim();
  var sign = 1;
  if (t.startsWith('-') || t.startsWith('−')) {
    sign = -1;
    t = t.substring(1);
  } else if (t.startsWith('+')) {
    t = t.substring(1);
  }
  final m = _money(t, what: 'the change, with a plus or minus sign');
  if (m.error != null) return (cents: null, note: null, error: m.error);
  if (m.cents == 0) return (cents: null, note: null, error: 'Enter a plus or minus amount, not 0.');
  final cents = sign * m.cents!;
  if (payableCents + cents < 0) return (cents: null, note: null, error: 'The amount owed cannot go below zero.');
  final problem = _note(reason, min: 3, max: 300, what: 'Say why the amount is changing (at least 3 characters).');
  if (problem != null) return (cents: null, note: null, error: problem);
  return (cents: cents, note: reason.trim(), error: null);
}

/// The payment that was made outside BottlesUp: exactly what was approved, a reference, and optionally a note about the evidence.
({int? cents, String? reference, String? evidence, String? error}) checkPaymentForm(String amount, String reference, String evidence, {required int payableCents, String currency = 'cad'}) {
  final m = _money(amount, what: 'the amount that was paid');
  if (m.error != null) return (cents: null, reference: null, evidence: null, error: m.error);
  if (m.cents != payableCents) return (cents: null, reference: null, evidence: null, error: 'The amount has to be exactly what was approved: ${settlementMoney(payableCents, currency: currency)}.');
  final r = reference.trim();
  if (r.length < 3) return (cents: null, reference: null, evidence: null, error: 'Enter a reference for the payment (at least 3 characters).');
  if (r.length > 120) return (cents: null, reference: null, evidence: null, error: 'Keep the reference to 120 characters or fewer.');
  final e = evidence.trim();
  if (e.length > 300) return (cents: null, reference: null, evidence: null, error: 'Keep the evidence note to 300 characters or fewer.');
  return (cents: m.cents, reference: r, evidence: e.isEmpty ? null : e, error: null);
}

/// A question from the organizer.
String? checkQuestion(String text) => _note(text, min: 5, max: 500, what: 'Say what you are asking (at least 5 characters).');

/// The club's answer to a question.
String? checkAnswer(String text) => _note(text, min: 3, max: 500, what: 'Write your answer (at least 3 characters).');

/// What a button says it does. The record is of an EXTERNAL payment: nothing is sent.
const String recordOnlyNote =
    'This is a record. BottlesUp does not pay organizers from here: when the club has paid the organizer some other way, the owner records that payment, with its reference. Tickets and tables are not part of this settlement, only the organizer\'s share of bar sales under the accepted agreement.';
