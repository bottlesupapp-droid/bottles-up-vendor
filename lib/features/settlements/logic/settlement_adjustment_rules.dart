import '../../agreements/logic/agreement_rules.dart' show parseMoneyToCents;
import '../../ops/logic/ops_json.dart';
import 'settlement_rules.dart';

// Adjustments AFTER a settlement was paid (website 20261125100000_settlement_adjustments.sql; brief sections 25 and 26, scenario 23 "Refund after settlement"). Record only, like the settlement:
// the paid settlement is never changed; an adjustment is a separate signed record beside it (a mistake is put right by an opposite one, never by editing). The database counts, decides who
// may do what (each adjustment says it, in `can`) and keeps the history; this file reads what it sends, words it, and checks what was typed before it is sent.

/// Sign: plus = the club owes the organizer MORE, minus = the organizer was paid too much. Shown with a plus or minus in front, never as a bare number.
String signedMoney(int cents, {String currency = 'cad'}) => '${cents > 0 ? '+' : ''}${settlementMoney(cents, currency: currency)}';

const List<String> adjustmentKinds = ['refund', 'chargeback', 'correction'];

String adjustmentKindLabel(String kind) => switch (kind) {
  'refund' => 'Refund',
  'chargeback' => 'Chargeback',
  'correction' => 'Correction',
  _ => 'Adjustment',
};

/// What each kind means, for the form.
String adjustmentKindHint(String kind) => switch (kind) {
  'refund' => 'A bottle or an order in the eligible sales was refunded after the organizer was paid. It takes money off.',
  'chargeback' => 'A card payment in the eligible sales was charged back. It takes money off.',
  'correction' => 'Puts an earlier adjustment right, or adds something back (a chargeback that was won, for example). Use a plus or a minus.',
  _ => '',
};

class AdjustmentStatusInfo {
  const AdjustmentStatusInfo(this.label, this.note, this.tone);

  final String label;
  final String note;
  final SettlementTone tone;
}

/// What a status of one adjustment says. Settled and waived are final.
AdjustmentStatusInfo adjustmentStatusInfo(String status) => switch (status) {
  'open' => const AdjustmentStatusInfo('Open', 'Waiting to be settled', SettlementTone.attention),
  'disputed' => const AdjustmentStatusInfo('Disputed', 'The organizer has asked a question', SettlementTone.bad),
  'settled' => const AdjustmentStatusInfo('Settled', 'Recorded external payment', SettlementTone.good),
  'waived' => const AdjustmentStatusInfo('Not recovered', 'The club chose not to recover it', SettlementTone.neutral),
  _ => const AdjustmentStatusInfo('Unknown', '', SettlementTone.neutral),
};

/// Which way the money goes, in words, for an adjustment of [cents] (signed). [club] and [organizer] are the two names.
String adjustmentOwesText({required String direction, required int cents, required String club, required String organizer, String currency = 'cad'}) {
  final amount = settlementMoney(cents.abs(), currency: currency);
  return direction == 'club_owes_organizer' ? '$club owes $organizer $amount' : '$organizer was paid too much: they owe $club $amount';
}

/// What became of an adjustment that is closed, in words (the same two names).
String adjustmentOutcomeText({required String status, required String direction, required int cents, required String club, required String organizer, String currency = 'cad'}) {
  final amount = settlementMoney(cents.abs(), currency: currency);
  return switch (status) {
    'settled' => direction == 'club_owes_organizer' ? '$club paid $organizer $amount' : '$organizer paid $club $amount back',
    'waived' => '$club chose not to recover $amount from $organizer',
    _ => adjustmentOwesText(direction: direction, cents: cents, club: club, organizer: organizer, currency: currency),
  };
}

/// What the person may do about one adjustment, as the database says it.
class AdjustmentCan {
  const AdjustmentCan({this.acknowledge = false, this.question = false, this.answer = false, this.settle = false, this.waive = false});

  final bool acknowledge;
  final bool question;
  final bool answer;
  final bool settle;
  final bool waive;

  bool get any => acknowledge || question || answer || settle || waive;
}

AdjustmentCan _parseItemCan(Object? v) {
  if (v is! Map) return const AdjustmentCan();
  bool b(String k) => v[k] == true;
  return AdjustmentCan(acknowledge: b('acknowledge'), question: b('question'), answer: b('answer'), settle: b('settle'), waive: b('waive'));
}

/// One adjustment after payment.
class SettlementAdjustment {
  const SettlementAdjustment({
    required this.id,
    required this.kind,
    required this.amountCents,
    required this.direction,
    required this.reason,
    required this.status,
    required this.can,
    this.sourceRef,
    this.recordedAt,
    this.recordedByName,
    this.disputedReason,
    this.disputedAt,
    this.acknowledgedAt,
    this.acknowledgedByName,
    this.resolvedAmountCents,
    this.resolvedOn,
    this.resolutionReference,
    this.resolutionNote,
    this.resolvedAt,
    this.resolvedByName,
    this.resolutionLabel,
  });

  final String id;
  final String kind;

  /// Signed: minus = the organizer was paid too much, plus = the club owes the organizer more.
  final int amountCents;
  final String direction;
  final String reason;
  final String? sourceRef;
  final String status;
  final DateTime? recordedAt;
  final String? recordedByName;
  final String? disputedReason;
  final DateTime? disputedAt;
  final DateTime? acknowledgedAt;
  final String? acknowledgedByName;
  final int? resolvedAmountCents;
  final DateTime? resolvedOn;
  final String? resolutionReference;
  final String? resolutionNote;
  final DateTime? resolvedAt;
  final String? resolvedByName;
  final String? resolutionLabel;
  final AdjustmentCan can;

  bool get isClosed => status == 'settled' || status == 'waived';
}

SettlementAdjustment? _parseAdjustment(Object? v) {
  if (v is! Map) return null;
  final m = Map<String, dynamic>.from(v);
  final id = opsStr(m, 'id');
  final kind = opsStr(m, 'kind');
  final status = opsStr(m, 'status');
  final amount = m['amount_cents'];
  if (id == null || kind == null || status == null || amount is! num || amount == 0) return null;
  final cents = amount.round();
  return SettlementAdjustment(
    id: id,
    kind: kind,
    amountCents: cents,
    direction: opsStr(m, 'direction') ?? (cents < 0 ? 'organizer_owes_club' : 'club_owes_organizer'),
    reason: opsStr(m, 'reason') ?? '',
    sourceRef: opsStr(m, 'source_ref'),
    status: status,
    recordedAt: opsTime(m, 'recorded_at'),
    recordedByName: opsStr(m, 'recorded_by_name'),
    disputedReason: opsStr(m, 'disputed_reason'),
    disputedAt: opsTime(m, 'disputed_at'),
    acknowledgedAt: opsTime(m, 'organizer_ack_at'),
    acknowledgedByName: opsStr(m, 'organizer_ack_by_name'),
    resolvedAmountCents: m['resolved_amount_cents'] is num ? (m['resolved_amount_cents'] as num).round() : null,
    resolvedOn: opsTime(m, 'resolved_on'),
    resolutionReference: opsStr(m, 'resolution_reference'),
    resolutionNote: opsStr(m, 'resolution_note'),
    resolvedAt: opsTime(m, 'resolved_at'),
    resolvedByName: opsStr(m, 'resolved_by_name'),
    resolutionLabel: opsStr(m, 'resolution_label'),
    can: _parseItemCan(m['can']),
  );
}

/// One line of the adjustments' history.
class AdjustmentLogEntry {
  const AdjustmentLogEntry({required this.adjustmentId, required this.at, required this.side, required this.action, required this.byName, required this.byMe, this.amountCents, this.note});

  final String adjustmentId;
  final DateTime? at;
  final String side;
  final String action;
  final int? amountCents;
  final String? note;
  final String byName;
  final bool byMe;
}

AdjustmentLogEntry? _parseAdjustmentLog(Object? v) {
  if (v is! Map) return null;
  final m = Map<String, dynamic>.from(v);
  final action = opsStr(m, 'action');
  final adjustment = opsStr(m, 'adjustment_id');
  if (action == null || adjustment == null) return null;
  return AdjustmentLogEntry(
    adjustmentId: adjustment,
    at: opsTime(m, 'at'),
    side: opsStr(m, 'side') ?? 'venue',
    action: action,
    amountCents: m['amount_cents'] is num ? (m['amount_cents'] as num).round() : null,
    note: opsStr(m, 'note'),
    byName: opsStr(m, 'by_name') ?? 'Someone',
    byMe: opsBool(m, 'by_me'),
  );
}

/// What a line of the adjustments' history says: what was done and by whom (the club or the organizer).
String adjustmentLogLine(AdjustmentLogEntry e, {String currency = 'cad'}) {
  String money(int? c, {bool signed = false}) => c == null ? '' : ' ${signed ? signedMoney(c, currency: currency) : settlementMoney(c.abs(), currency: currency)}';
  final what = switch (e.action) {
    'recorded' => 'Adjustment recorded${money(e.amountCents, signed: true)}',
    'acknowledged' => 'Acknowledged${money(e.amountCents, signed: true)}',
    'questioned' => 'Question asked',
    'answered' => 'Question answered',
    'settled' => 'Payment recorded${money(e.amountCents)}',
    'waived' => 'Not recovered${money(e.amountCents)}',
    _ => e.action,
  };
  return '$what · ${e.side == 'organizer' ? 'Organizer' : 'Club'}';
}

/// All the adjustments of one paid settlement, with the totals the database worked out.
class SettlementAdjustments {
  const SettlementAdjustments({
    required this.agreementId,
    required this.side,
    required this.applies,
    required this.items,
    required this.log,
    required this.canRecord,
    this.settlementId,
    this.currency = 'cad',
    this.paidAmountCents = 0,
    this.paidOn,
    this.count = 0,
    this.adjustmentsCents = 0,
    this.netCents = 0,
    this.openToOrganizerCents = 0,
    this.openToClubCents = 0,
  });

  final String agreementId;
  final String? settlementId;

  /// 'venue' (the club's manager or owner) or 'organizer'.
  final String side;

  /// Only a settlement that has been paid takes adjustments after payment.
  final bool applies;
  final String currency;
  final int paidAmountCents;
  final DateTime? paidOn;
  final int count;

  /// The sum of every adjustment (signed).
  final int adjustmentsCents;

  /// What was paid plus the adjustments: what the organizer is owed after them. Never below zero.
  final int netCents;

  /// Still to be settled, in each direction, never netted against each other.
  final int openToOrganizerCents;
  final int openToClubCents;
  final List<SettlementAdjustment> items;
  final List<AdjustmentLogEntry> log;
  final bool canRecord;

  bool get isEmpty => items.isEmpty;
}

SettlementAdjustments? parseSettlementAdjustments(Map<String, dynamic> r) {
  final agreement = opsStr(r, 'agreement_id');
  if (agreement == null) return null;
  return SettlementAdjustments(
    agreementId: agreement,
    settlementId: opsStr(r, 'settlement_id'),
    side: opsStr(r, 'side') ?? 'venue',
    applies: opsBool(r, 'applies'),
    currency: opsStr(r, 'currency') ?? 'cad',
    paidAmountCents: opsInt(r, 'paid_amount_cents'),
    paidOn: opsTime(r, 'paid_on'),
    count: opsInt(r, 'count'),
    adjustmentsCents: opsInt(r, 'adjustments_cents'),
    netCents: opsInt(r, 'net_cents'),
    openToOrganizerCents: opsInt(r, 'open_to_organizer_cents'),
    openToClubCents: opsInt(r, 'open_to_club_cents'),
    items:
        [
          if (r['items'] is List)
            for (final e in r['items'] as List) _parseAdjustment(e),
        ].whereType<SettlementAdjustment>().toList(),
    log:
        [
          if (r['log'] is List)
            for (final e in r['log'] as List) _parseAdjustmentLog(e),
        ].whereType<AdjustmentLogEntry>().toList(),
    canRecord: r['can'] is Map && (r['can'] as Map)['record'] == true,
  );
}

/// The figures at the top, line by line: what was paid (unchanged), what the adjustments come to, what the organizer is owed after them, and what is still to be settled each way.
List<({String label, String value, bool strong})> adjustmentSummaryLines(SettlementAdjustments a, {required String club, required String organizer}) {
  String m(int c) => settlementMoney(c, currency: a.currency);
  return [
    (label: 'Paid (as recorded, unchanged)', value: m(a.paidAmountCents), strong: false),
    if (a.count > 0) (label: 'Adjustments after payment', value: signedMoney(a.adjustmentsCents, currency: a.currency), strong: false),
    (label: 'Amount owed to the organizer after adjustments', value: m(a.netCents), strong: true),
    if (a.openToClubCents > 0) (label: 'Still to come back from $organizer', value: m(a.openToClubCents), strong: false),
    if (a.openToOrganizerCents > 0) (label: 'Still to pay $organizer', value: m(a.openToOrganizerCents), strong: false),
  ];
}

/// A row of the list: how many adjustments a settlement has, how many are still open, and what is still to come in each direction.
class AdjustmentFlag {
  const AdjustmentFlag({required this.agreementId, required this.count, required this.openCount, required this.openToOrganizerCents, required this.openToClubCents});

  final String agreementId;
  final int count;
  final int openCount;
  final int openToOrganizerCents;
  final int openToClubCents;
}

AdjustmentFlag? parseAdjustmentFlag(Map<String, dynamic> r) {
  final id = opsStr(r, 'agreement_id');
  if (id == null) return null;
  return AdjustmentFlag(
    agreementId: id,
    count: opsInt(r, 'adjustment_count'),
    openCount: opsInt(r, 'open_count'),
    openToOrganizerCents: opsInt(r, 'open_to_organizer_cents'),
    openToClubCents: opsInt(r, 'open_to_club_cents'),
  );
}

/// The line a list row shows under a paid settlement that has adjustments.
String adjustmentFlagText(AdjustmentFlag f) {
  final n = f.count == 1 ? '1 adjustment after payment' : '${f.count} adjustments after payment';
  if (f.openCount == 0) return '$n, all settled';
  return '$n, ${f.openCount} still open';
}

// ---------------------------------------------------------------------------
// What was typed, checked the way the database will check it
// ---------------------------------------------------------------------------

/// Recording an adjustment. A refund or a chargeback is typed as a plain amount ("50.00": the app makes it a minus); a correction needs its plus or minus. [netCents] is what the organizer is
/// owed after the adjustments so far: nothing can take back more than that. [reference] is optional (3 to 120 characters).
({int? cents, String? kind, String? reason, String? reference, String? error}) checkAdjustmentRecordForm({
  required String? kind,
  required String amount,
  required String reason,
  required String reference,
  required int netCents,
  String currency = 'cad',
}) {
  ({int? cents, String? kind, String? reason, String? reference, String? error}) no(String error) => (cents: null, kind: null, reason: null, reference: null, error: error);
  if (kind == null || !adjustmentKinds.contains(kind)) return no('Choose what the adjustment is for: a refund, a chargeback or a correction.');
  var t = amount.trim();
  if (t.isEmpty) return no('Enter the amount, for example 50.00.');
  var sign = 0;
  if (t.startsWith('-') || t.startsWith('−')) {
    sign = -1;
    t = t.substring(1).trim();
  } else if (t.startsWith('+')) {
    sign = 1;
    t = t.substring(1).trim();
  }
  final parsed = parseMoneyToCents(t);
  if (parsed == null) return no('Enter an amount like 50 or 50.00.');
  if (parsed == 0) return no('Enter an amount, not 0.');
  int cents;
  if (kind == 'correction') {
    if (sign == 0) return no('A correction needs a plus or a minus, for example +15.00 or -15.00.');
    cents = sign * parsed;
  } else {
    if (sign > 0) return no('A ${kind == 'refund' ? 'refund' : 'chargeback'} takes money off: enter the amount without a plus sign.');
    cents = -parsed;
  }
  if (netCents + cents < 0) return no('The adjustments cannot take back more than was paid: at most ${settlementMoney(netCents, currency: currency)} can still be taken off.');
  final r = reason.trim();
  if (r.length < 3) return no('Say why (at least 3 characters).');
  if (r.length > 300) return no('Keep the reason to 300 characters or fewer.');
  final ref = reference.trim();
  if (ref.isNotEmpty && ref.length < 3) return no('A reference is at least 3 characters (or leave it empty).');
  if (ref.length > 120) return no('Keep the reference to 120 characters or fewer.');
  return (cents: cents, kind: kind, reason: r, reference: ref.isEmpty ? null : ref, error: null);
}

/// The payment that settles an adjustment, made outside BottlesUp: exactly the adjustment (without its sign), a reference, and optionally a note about the evidence.
({int? cents, String? reference, String? evidence, String? error}) checkAdjustmentSettleForm(String amount, String reference, String evidence, {required int adjustmentCents, String currency = 'cad'}) {
  ({int? cents, String? reference, String? evidence, String? error}) no(String error) => (cents: null, reference: null, evidence: null, error: error);
  if (amount.trim().isEmpty) return no('Enter the amount that was paid.');
  final cents = parseMoneyToCents(amount.trim());
  if (cents == null) return no('Enter an amount like 50 or 50.00.');
  final want = adjustmentCents.abs();
  if (cents != want) return no('The amount has to be exactly the adjustment: ${settlementMoney(want, currency: currency)}.');
  final r = reference.trim();
  if (r.length < 3) return no('Enter a reference for the payment (at least 3 characters).');
  if (r.length > 120) return no('Keep the reference to 120 characters or fewer.');
  final e = evidence.trim();
  if (e.length > 300) return no('Keep the evidence note to 300 characters or fewer.');
  return (cents: cents, reference: r, evidence: e.isEmpty ? null : e, error: null);
}

/// Why the club is not recovering an amount the organizer was paid too much.
String? checkWaiveReason(String text) {
  final t = text.trim();
  if (t.length < 3) return 'Say why it is not being recovered (at least 3 characters).';
  if (t.length > 300) return 'Keep it to 300 characters or fewer.';
  return null;
}

/// Said under every adjustments section.
const String adjustmentsNote =
    'The payment above is kept exactly as it was recorded. An adjustment is a separate record beside it, with its own history: a refund or a chargeback that came after the organizer was paid. Nothing is paid or taken back from here; when the money moves, the owner records that payment, with its reference. An adjustment is not taken off a later settlement.';

/// What the owner is told before an adjustment is recorded (it cannot be edited or removed afterwards).
const String adjustmentRecordWarning = 'An adjustment cannot be edited or removed once it is recorded. If it is a mistake, record an opposite correction.';
