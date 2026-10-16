import '../../ops/logic/ops_json.dart';
import '../../owner/logic/setup_forms.dart' show formatDollars, parseMoney;

/// Cash handed in at the end of a night, and payments flagged for a manager (the payment verifier's Cash / Exceptions / Summary).
/// Everything the database decides (who may see or do what, that nobody counts their own handover, that cash is handed in once) is
/// decided there; this file only reads what it sends and checks what a person typed before it is sent.

// ---------------------------------------------------------------------------
// Cash held and handed in
// ---------------------------------------------------------------------------
class CashLine {
  const CashLine({required this.collectorName, required this.isMe, required this.collectedCents, required this.handedInCents, required this.heldCents});

  final String collectorName;
  final bool isMe;
  final int collectedCents;
  final int handedInCents;
  final int heldCents;
}

CashLine? parseCashLine(Map<String, dynamic> r) => CashLine(
      collectorName: opsStr(r, 'collector_name') ?? 'Staff member',
      isMe: opsBool(r, 'is_me'),
      collectedCents: opsInt(r, 'collected_cents'),
      handedInCents: opsInt(r, 'handed_in_cents'),
      heldCents: opsInt(r, 'held_cents'),
    );

class Handover {
  const Handover({
    required this.id,
    required this.collectorName,
    required this.isMine,
    required this.claimedCents,
    required this.status,
    this.submittedAt,
    this.note,
    this.receivedByName,
    this.receivedAt,
    this.countedCents,
    this.differenceCents,
    this.receiveNote,
  });

  final String id;
  final String collectorName;
  final bool isMine;
  final int claimedCents;
  final String status;
  final DateTime? submittedAt;
  final String? note;
  final String? receivedByName;
  final DateTime? receivedAt;
  final int? countedCents;
  final int? differenceCents;
  final String? receiveNote;

  bool get waiting => status == 'submitted';
  bool get acknowledged => status == 'acknowledged';
}

Handover? parseHandover(Map<String, dynamic> r) {
  final id = opsStr(r, 'handover_id');
  if (id == null) return null;
  return Handover(
    id: id,
    collectorName: opsStr(r, 'collector_name') ?? 'Staff member',
    isMine: opsBool(r, 'is_mine'),
    claimedCents: opsInt(r, 'claimed_cents'),
    status: opsStr(r, 'status') ?? 'submitted',
    submittedAt: opsTime(r, 'submitted_at'),
    note: opsStr(r, 'note'),
    receivedByName: opsStr(r, 'received_by_name'),
    receivedAt: opsTime(r, 'received_at'),
    countedCents: r['counted_cents'] == null ? null : opsInt(r, 'counted_cents'),
    differenceCents: r['difference_cents'] == null ? null : opsInt(r, 'difference_cents'),
    receiveNote: opsStr(r, 'receive_note'),
  );
}

/// "Matches", "Short $1.00" or "Over $1.00": a difference is said in words, never as a bare minus sign.
String differenceLabel(int cents) => cents == 0 ? 'Matches' : (cents < 0 ? 'Short ${formatDollars(-cents)}' : 'Over ${formatDollars(cents)}');

// ---------------------------------------------------------------------------
// What a person types
// ---------------------------------------------------------------------------
class AmountCheck {
  const AmountCheck.ok(this.cents) : error = null;
  const AmountCheck.bad(this.error) : cents = null;

  final int? cents;
  final String? error;
}

/// Cash handed in: a positive amount, no more than is held.
AmountCheck checkHandoverAmount(String text, int heldCents) {
  final cents = parseMoney(text);
  if (cents == null) return const AmountCheck.bad('Enter the amount you are handing over, for example 120.00.');
  if (cents <= 0) return const AmountCheck.bad('Enter an amount above zero.');
  if (cents > heldCents) return AmountCheck.bad('You only hold ${formatDollars(heldCents)}.');
  return AmountCheck.ok(cents);
}

/// Cash counted: any amount from zero.
AmountCheck checkCountedAmount(String text) {
  final cents = parseMoney(text);
  if (cents == null || cents < 0) return const AmountCheck.bad('Enter the amount you counted, for example 120.00.');
  return AmountCheck.ok(cents);
}

const int maxCashNote = 300;

String? checkCashNote(String note) => note.trim().length > maxCashNote ? 'Keep the note to $maxCashNote characters or fewer.' : null;

/// A difference between what was handed in and what was counted needs a reason (the database insists too).
String? checkCountReason({required int claimedCents, required int countedCents, required String note}) {
  final problem = checkCashNote(note);
  if (problem != null) return problem;
  if (countedCents != claimedCents && note.trim().length < 3) return 'The amount counted is different from the amount handed in: say why.';
  return null;
}

Map<String, dynamic> submitHandoverParams(String venueId, String night, int cents, String note) => {
      'p_venue': venueId,
      'p_night': night,
      'p_amount_cents': cents,
      'p_note': note.trim().isEmpty ? null : note.trim(),
    };

Map<String, dynamic> receiveHandoverParams(String handoverId, int countedCents, String note) => {
      'p_handover': handoverId,
      'p_counted_cents': countedCents,
      'p_note': note.trim().isEmpty ? null : note.trim(),
    };

// ---------------------------------------------------------------------------
// Flagged payments
// ---------------------------------------------------------------------------
class PaymentFlag {
  const PaymentFlag({
    required this.id,
    required this.paymentId,
    required this.customerName,
    required this.tableName,
    required this.paymentMethod,
    required this.amountPaidCents,
    required this.reason,
    required this.raisedByName,
    required this.raisedByMe,
    required this.status,
    this.confirmationCode,
    this.raisedAt,
    this.resolution,
    this.resolutionNote,
    this.resolvedByName,
    this.resolvedAt,
  });

  final String id;
  final String paymentId;
  final String? confirmationCode;
  final String customerName;
  final String tableName;
  final String paymentMethod;
  final int amountPaidCents;
  final String reason;
  final String raisedByName;
  final bool raisedByMe;
  final DateTime? raisedAt;
  final String status;
  final String? resolution;
  final String? resolutionNote;
  final String? resolvedByName;
  final DateTime? resolvedAt;

  bool get open => status == 'open';
}

PaymentFlag? parseFlag(Map<String, dynamic> r) {
  final id = opsStr(r, 'flag_id');
  final payment = opsStr(r, 'payment_id');
  if (id == null || payment == null) return null;
  return PaymentFlag(
    id: id,
    paymentId: payment,
    confirmationCode: opsStr(r, 'confirmation_code'),
    customerName: opsStr(r, 'customer_name') ?? 'Guest',
    tableName: opsStr(r, 'table_name') ?? 'Table',
    paymentMethod: opsStr(r, 'payment_method') ?? '',
    amountPaidCents: opsInt(r, 'amount_paid_cents'),
    reason: opsStr(r, 'reason') ?? '',
    raisedByName: opsStr(r, 'raised_by_name') ?? 'Staff member',
    raisedByMe: opsBool(r, 'raised_by_me'),
    raisedAt: opsTime(r, 'raised_at'),
    status: opsStr(r, 'status') ?? 'open',
    resolution: opsStr(r, 'resolution'),
    resolutionNote: opsStr(r, 'resolution_note'),
    resolvedByName: opsStr(r, 'resolved_by_name'),
    resolvedAt: opsTime(r, 'resolved_at'),
  );
}

/// How a flag can end, in the order the manager is offered them.
const List<(String, String)> flagResolutions = [
  ('confirmed_ok', 'Checked: the payment is fine'),
  ('corrected', 'The payment was corrected'),
  ('refunded', 'Refunded to the guest'),
  ('written_off', 'Written off'),
  ('other', 'Something else'),
];

String resolutionLabel(String? value) {
  for (final (v, label) in flagResolutions) {
    if (v == value) return label;
  }
  return value ?? '';
}

const int maxFlagReason = 500;

String? checkFlagReason(String text) {
  final t = text.trim();
  if (t.length < 3) return 'Say what is wrong with this payment.';
  if (t.length > maxFlagReason) return 'Keep the reason to $maxFlagReason characters or fewer.';
  return null;
}

/// "Checked: the payment is fine" needs no note; every other outcome says what was done.
String? checkResolution(String? resolution, String note) {
  if (resolution == null || !flagResolutions.any((r) => r.$1 == resolution)) return 'Choose how it was resolved.';
  if (note.trim().length > maxFlagReason) return 'Keep the note to $maxFlagReason characters or fewer.';
  if (resolution != 'confirmed_ok' && note.trim().length < 3) return 'Say what was done.';
  return null;
}

// ---------------------------------------------------------------------------
// The verifier's summary
// ---------------------------------------------------------------------------
class VerifierSummary {
  const VerifierSummary({
    required this.paymentsRecorded,
    required this.paymentsChecked,
    required this.paymentsToCheck,
    required this.paymentsDisputed,
    required this.checkedByMe,
    required this.flagsOpen,
    required this.flagsResolved,
    required this.handoversWaiting,
    required this.handoversAcknowledged,
    required this.cashDifferenceCents,
  });

  final int paymentsRecorded;
  final int paymentsChecked;
  final int paymentsToCheck;
  final int paymentsDisputed;
  final int checkedByMe;
  final int flagsOpen;
  final int flagsResolved;
  final int handoversWaiting;
  final int handoversAcknowledged;
  final int cashDifferenceCents;
}

VerifierSummary? parseVerifierSummary(Map<String, dynamic> r) => VerifierSummary(
      paymentsRecorded: opsInt(r, 'payments_recorded'),
      paymentsChecked: opsInt(r, 'payments_checked'),
      paymentsToCheck: opsInt(r, 'payments_to_check'),
      paymentsDisputed: opsInt(r, 'payments_disputed'),
      checkedByMe: opsInt(r, 'checked_by_me'),
      flagsOpen: opsInt(r, 'flags_open'),
      flagsResolved: opsInt(r, 'flags_resolved'),
      handoversWaiting: opsInt(r, 'handovers_waiting'),
      handoversAcknowledged: opsInt(r, 'handovers_acknowledged'),
      cashDifferenceCents: opsInt(r, 'cash_difference_cents'),
    );
