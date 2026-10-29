import '../../owner/logic/setup_forms.dart' show formatDollars, parseMoney, parseWhole;

// Refunds and cancellations (developer brief 15 Oct 2026, sections 26 and 31; the client's answers of 20 Oct: the venue authorises each refund, the guest is told; the owner's
// decision: refund deadlines and amounts are set by the venue itself and watched in the CMS). Pure Dart, tested without a screen. Every check mirrors the database function that finally
// decides (website repo, 20261023100000_refund_policy_and_requests.sql), so the form says what is wrong in plain words before anything is sent and the database still refuses whatever
// gets past it.

int? _int(Object? v) => v is num ? v.toInt() : int.tryParse('$v');
String? _text(Object? v) {
  final s = v?.toString().trim();
  return s == null || s.isEmpty ? null : s;
}

// ---------------------------------------------------------------------------
// The venue's refund policy
// ---------------------------------------------------------------------------

/// A rule: "cancel at least [hours] hours before arrival: [percent] percent of the deposit back".
class RefundTier {
  const RefundTier({required this.hours, required this.percent});

  final int hours;
  final int percent;

  @override
  bool operator ==(Object other) => other is RefundTier && other.hours == hours && other.percent == percent;

  @override
  int get hashCode => Object.hash(hours, percent);
}

/// The most rules a policy can have, and the longest notice a rule can ask for (90 days), and the longest note.
const int maxRefundRules = 6;
const int maxRefundHours = 2160;
const int maxPolicyNote = 300;

/// The venue's policy as the database holds it. [hasPolicy] false = the venue has not set one (refunds are then its own decision).
class RefundPolicy {
  const RefundPolicy({required this.hasPolicy, required this.tiers, required this.noRefundAfterCheckIn, this.note, required this.lines});

  final bool hasPolicy;
  final List<RefundTier> tiers;
  final bool noRefundAfterCheckIn;
  final String? note;

  /// The policy in the sentences a guest reads (the database's own wording).
  final List<String> lines;
}

RefundPolicy? parseRefundPolicy(Map<String, dynamic> r) {
  if (!r.containsKey('has_policy')) return null;
  final tiers = <RefundTier>[];
  final raw = r['tiers'];
  if (raw is List) {
    for (final t in raw) {
      if (t is! Map) continue;
      final h = _int(t['hours']);
      final p = _int(t['percent']);
      if (h == null || p == null) continue;
      tiers.add(RefundTier(hours: h, percent: p));
    }
  }
  final lines = r['lines'];
  return RefundPolicy(
    hasPolicy: r['has_policy'] == true,
    tiers: tiers,
    noRefundAfterCheckIn: r['no_refund_after_check_in'] != false,
    note: _text(r['note']),
    lines: lines is List ? [for (final l in lines) if (_text(l) != null) l.toString()] : const [],
  );
}

/// The policy in plain sentences, most notice first: the same words the database writes (`refund_policy_lines`), so the editor can show a guest's view as it is built.
List<String> refundPolicyLines({required List<RefundTier> tiers, required bool noRefundAfterCheckIn, String? note, bool hasPolicy = true}) {
  if (!hasPolicy) return const ['This venue has not set a refund policy: refunds are decided by the venue.'];
  final lines = <String>[];
  if (tiers.isEmpty) {
    lines.add('The deposit is not refundable.');
  } else {
    final sorted = [...tiers]..sort((a, b) => b.hours.compareTo(a.hours));
    for (final t in sorted) {
      final notice = t.hours == 0
          ? 'Cancel any time before you arrive: '
          : t.hours % 24 == 0
              ? 'Cancel at least ${t.hours ~/ 24} ${t.hours == 24 ? 'day' : 'days'} before you arrive: '
              : 'Cancel at least ${t.hours} ${t.hours == 1 ? 'hour' : 'hours'} before you arrive: ';
      final back = t.percent == 100 ? 'the whole deposit is refunded.' : (t.percent == 0 ? 'no refund.' : '${t.percent}% of the deposit is refunded.');
      lines.add('$notice$back');
    }
    if (sorted.last.hours > 0) lines.add('Later than that: no refund.');
  }
  if (noRefundAfterCheckIn) lines.add('Once the guests have arrived there is no refund.');
  final n = note?.trim() ?? '';
  if (n.isNotEmpty) lines.add(n);
  return lines;
}

/// One rule as typed.
class TierForm {
  const TierForm({this.hours = '', this.percent = ''});

  final String hours;
  final String percent;

  TierForm copyWith({String? hours, String? percent}) => TierForm(hours: hours ?? this.hours, percent: percent ?? this.percent);
}

class RefundPolicyForm {
  const RefundPolicyForm({this.tiers = const [], this.noRefundAfterCheckIn = true, this.note = ''});

  final List<TierForm> tiers;
  final bool noRefundAfterCheckIn;
  final String note;
}

RefundPolicyForm policyFormFrom(RefundPolicy? p) => p == null || !p.hasPolicy
    ? const RefundPolicyForm(tiers: [TierForm(hours: '48', percent: '100'), TierForm(hours: '24', percent: '50')])
    : RefundPolicyForm(
        tiers: [for (final t in p.tiers) TierForm(hours: '${t.hours}', percent: '${t.percent}')],
        noRefundAfterCheckIn: p.noRefundAfterCheckIn,
        note: p.note ?? '',
      );

/// What is wrong with the policy, in plain words. Empty means it can be sent.
List<String> validatePolicy(RefundPolicyForm f) {
  final out = <String>[];
  if (f.tiers.length > maxRefundRules) out.add('A refund policy can have $maxRefundRules rules at most.');
  final parsed = <RefundTier>[];
  var rule = 0;
  for (final t in f.tiers) {
    rule++;
    final h = parseWhole(t.hours);
    final p = parseWhole(t.percent);
    if (h == null || h > maxRefundHours) {
      out.add('Rule $rule: give the hours of notice as a whole number from 0 to $maxRefundHours.');
    }
    if (p == null || p > 100) out.add('Rule $rule: give the percent refunded as a whole number from 0 to 100.');
    if (h != null && h <= maxRefundHours && p != null && p <= 100) parsed.add(RefundTier(hours: h, percent: p));
  }
  if (parsed.length == f.tiers.length) {
    if (parsed.map((t) => t.hours).toSet().length != parsed.length) {
      out.add('Two rules cannot have the same hours of notice.');
    } else {
      final sorted = [...parsed]..sort((a, b) => b.hours.compareTo(a.hours));
      for (var i = 1; i < sorted.length; i++) {
        if (sorted[i].percent > sorted[i - 1].percent) {
          out.add('Giving more notice cannot get less back: a rule with fewer hours cannot refund a larger percent.');
          break;
        }
      }
    }
  }
  if (f.note.trim().length > maxPolicyNote) out.add('The note can be up to $maxPolicyNote characters.');
  return out;
}

/// The payload of save_venue_refund_policy: all three keys every time (a key that is left out stays as it was, and a blank note clears it).
Map<String, dynamic> policyPayload(RefundPolicyForm f) {
  final tiers = [for (final t in f.tiers) RefundTier(hours: parseWhole(t.hours)!, percent: parseWhole(t.percent)!)]..sort((a, b) => b.hours.compareTo(a.hours));
  final note = f.note.trim();
  return {
    'tiers': [for (final t in tiers) {'hours': t.hours, 'percent': t.percent}],
    'no_refund_after_check_in': f.noRefundAfterCheckIn,
    'note': note.isEmpty ? null : note,
  };
}

/// The guest's view of the policy being edited, before it is saved.
List<String> previewLines(RefundPolicyForm f) {
  if (validatePolicy(f).isNotEmpty) return const [];
  return refundPolicyLines(
    tiers: [for (final t in f.tiers) RefundTier(hours: parseWhole(t.hours)!, percent: parseWhole(t.percent)!)],
    noRefundAfterCheckIn: f.noRefundAfterCheckIn,
    note: f.note,
  );
}

/// Whether saving would change the policy as it is now.
bool policyChanged(RefundPolicy? saved, RefundPolicyForm f) {
  if (saved == null || !saved.hasPolicy) return true;
  if (validatePolicy(f).isNotEmpty) return true;
  final now = policyPayload(f);
  final a = (now['tiers'] as List).map((t) => '${(t as Map)['hours']}:${t['percent']}').join(',');
  final sorted = [...saved.tiers]..sort((x, y) => y.hours.compareTo(x.hours));
  final b = sorted.map((t) => '${t.hours}:${t.percent}').join(',');
  return a != b || now['no_refund_after_check_in'] != saved.noRefundAfterCheckIn || (now['note'] ?? '') != (saved.note ?? '');
}

// ---------------------------------------------------------------------------
// Requests
// ---------------------------------------------------------------------------

enum RefundStatus {
  requested('requested', 'Waiting for a decision'),
  approved('approved', 'Approved'),
  declined('declined', 'Declined'),
  processing('processing', 'Being returned'),
  completed('completed', 'Paid back'),
  failed('failed', 'Could not be returned');

  const RefundStatus(this.db, this.label);

  final String db;
  final String label;

  static RefundStatus? fromDb(String? v) {
    for (final s in values) {
      if (s.db == v) return s;
    }
    return null;
  }

  /// A request that is still open: nothing else can be asked for the booking until it ends.
  bool get isOpen => this == requested || this == approved || this == processing;
}

/// How an approved refund is paid back.
enum RefundMethod {
  online('online', 'Returned to the card through BottlesUp'),
  club('club', 'Paid back at the club');

  const RefundMethod(this.db, this.label);

  final String db;
  final String label;

  static RefundMethod? fromDb(String? v) {
    for (final m in values) {
      if (m.db == v) return m;
    }
    return null;
  }
}

class RefundRequest {
  const RefundRequest({
    required this.requestId,
    required this.bookingId,
    this.code,
    required this.guestName,
    required this.tableName,
    required this.bookingDate,
    required this.byGuest,
    required this.reason,
    required this.status,
    required this.paidCents,
    required this.availableCents,
    this.policyPercent,
    required this.suggestedCents,
    this.approvedCents,
    this.method,
    this.decisionNote,
    this.failureNote,
    this.reference,
    this.receiptPath,
    required this.createdAt,
  });

  final String requestId;
  final String bookingId;
  final String? code;
  final String guestName;
  final String tableName;
  final String bookingDate;
  final bool byGuest;
  final String reason;
  final RefundStatus status;
  final int paidCents;
  final int availableCents;
  final int? policyPercent;
  final int suggestedCents;
  final int? approvedCents;
  final RefundMethod? method;
  final String? decisionNote;
  final String? failureNote;

  /// The terminal or receipt reference a refund paid back at the club was recorded with, and the photo of the receipt (a path in the private receipts bucket).
  final String? reference;
  final String? receiptPath;
  final DateTime createdAt;

  bool get hasReceiptPhoto => receiptPath != null;

  bool get canDecide => status == RefundStatus.requested;
  bool get needsClubPayment => status == RefundStatus.approved && method == RefundMethod.club;
  bool get waitsForBottlesUp => status == RefundStatus.approved && method == RefundMethod.online;
}

RefundRequest? parseRefundRequest(Map<String, dynamic> r) {
  final id = _text(r['request_id']);
  final booking = _text(r['booking_id']);
  final status = RefundStatus.fromDb(_text(r['status']));
  final created = DateTime.tryParse(r['created_at']?.toString() ?? '');
  final reason = _text(r['reason']);
  if (id == null || booking == null || status == null || created == null || reason == null) return null;
  return RefundRequest(
    requestId: id,
    bookingId: booking,
    code: _text(r['confirmation_code']),
    guestName: _text(r['guest_name']) ?? 'Guest',
    tableName: _text(r['table_name']) ?? 'Table',
    bookingDate: _text(r['booking_date']) ?? '',
    byGuest: r['requested_by_kind'] == 'guest',
    reason: reason,
    status: status,
    paidCents: _int(r['paid_cents']) ?? 0,
    availableCents: _int(r['available_cents']) ?? 0,
    policyPercent: _int(r['policy_percent']),
    suggestedCents: _int(r['suggested_cents']) ?? 0,
    approvedCents: _int(r['approved_cents']),
    method: RefundMethod.fromDb(_text(r['method'])),
    decisionNote: _text(r['decision_note']),
    failureNote: _text(r['failure_note']),
    reference: _text(r['refund_reference']),
    receiptPath: _text(r['refund_receipt_path']),
    createdAt: created.toLocal(),
  );
}

/// What the policy suggests, in words: "The policy suggests 50% = $12.50" or "No policy: the amount is yours to decide."
String suggestionLine(RefundRequest r) {
  final p = r.policyPercent;
  if (p == null) return 'This booking has no refund policy, so the amount is yours to decide.';
  return 'The policy suggests $p% of the deposit: ${formatDollars(r.suggestedCents)}.';
}

/// Where a request stands, in a sentence for the list.
String requestStatusLine(RefundRequest r) {
  final amount = r.approvedCents == null ? '' : formatDollars(r.approvedCents!);
  return switch (r.status) {
    RefundStatus.requested => 'Waiting for your decision',
    RefundStatus.approved => r.method == RefundMethod.club
        ? '$amount approved: pay it back at the club, then record it'
        : '$amount approved: BottlesUp returns it to the guest\'s card',
    RefundStatus.declined => 'Declined${r.decisionNote == null ? '' : ': ${r.decisionNote}'}',
    RefundStatus.processing => '$amount is being returned to the guest\'s card',
    RefundStatus.completed => '$amount paid back${r.method == RefundMethod.club ? ' at the club' : ' to the guest\'s card'}${r.reference == null ? '' : ' · reference ${r.reference}'}',
    RefundStatus.failed => 'The card refund did not go through${r.failureNote == null ? '' : ': ${r.failureNote}'}. BottlesUp has been told.',
  };
}

enum RefundFilter {
  open('Open'),
  all('All');

  const RefundFilter(this.label);

  final String label;

  bool matches(RefundRequest r) => this == all || r.status.isOpen || r.status == RefundStatus.failed;
}

// ---------------------------------------------------------------------------
// Asking, deciding, recording
// ---------------------------------------------------------------------------

/// The booking's own policy applied now, and what can still be refunded (desk_refund_options).
class RefundOptions {
  const RefundOptions({
    required this.paidCents,
    required this.depositCents,
    required this.availableCents,
    this.hoursToArrival,
    required this.checkedIn,
    required this.paidOnline,
    required this.status,
    required this.policyLines,
    this.percent,
    required this.suggestedCents,
    this.why,
    this.openRequestId,
  });

  final int paidCents;
  final int depositCents;
  final int availableCents;
  final double? hoursToArrival;
  final bool checkedIn;
  final bool paidOnline;
  final String status;
  final List<String> policyLines;
  final int? percent;
  final int suggestedCents;
  final String? why;
  final String? openRequestId;

  bool get hasOpenRequest => openRequestId != null;

  /// Something paid and still left to give back, on a booking that is confirmed or cancelled.
  bool get canAsk => (status == 'paid' || status == 'cancelled') && availableCents > 0 && !hasOpenRequest;
}

RefundOptions? parseRefundOptions(dynamic data) {
  if (data is! Map) return null;
  final r = Map<String, dynamic>.from(data);
  if (!r.containsKey('available_cents')) return null;
  final lines = r['policy_lines'];
  final hours = r['hours_to_arrival'];
  return RefundOptions(
    paidCents: _int(r['paid_cents']) ?? 0,
    depositCents: _int(r['deposit_cents']) ?? 0,
    availableCents: _int(r['available_cents']) ?? 0,
    hoursToArrival: hours is num ? hours.toDouble() : double.tryParse('$hours'),
    checkedIn: r['checked_in'] == true,
    paidOnline: r['paid_online'] == true,
    status: _text(r['status']) ?? '',
    policyLines: lines is List ? [for (final l in lines) if (_text(l) != null) l.toString()] : const [],
    percent: _int(r['percent']),
    suggestedCents: _int(r['suggested_cents']) ?? 0,
    why: _text(r['why']),
    openRequestId: _text(r['open_request_id']),
  );
}

/// "3 days 4 hours before the guests arrive" or "The guests' arrival time has passed".
String arrivalLine(double? hours) {
  if (hours == null) return '';
  if (hours <= 0) return 'The guests\' arrival time has passed.';
  final total = hours.floor();
  if (total >= 48) return 'The guests arrive in ${total ~/ 24} days.';
  if (total >= 1) return 'The guests arrive in $total ${total == 1 ? 'hour' : 'hours'}.';
  return 'The guests arrive in less than an hour.';
}

/// What is wrong with the reason for a refund request (staff side: 3 to 500 characters).
String? validateRequestReason(String reason) {
  final r = reason.trim();
  return r.length < 3 || r.length > 500 ? 'Give a reason of 3 to 500 characters.' : null;
}

class DecisionForm {
  const DecisionForm({required this.approve, this.amountText = '', this.method, this.note = ''});

  final bool approve;
  final String amountText;
  final RefundMethod? method;
  final String note;
}

/// What is wrong with a decision, in plain words. Empty means it can be sent.
List<String> validateDecision(DecisionForm f, RefundRequest r, {required bool paidOnline}) {
  final out = <String>[];
  final note = f.note.trim();
  if (note.length > 500) out.add('The note can be up to 500 characters.');
  if (!f.approve) {
    if (note.length < 3) out.add('Say why the refund is declined, so the guest can be told.');
    return out;
  }
  final cents = parseMoney(f.amountText);
  if (f.method == null) out.add('Choose how it is paid back: to the card through BottlesUp, or at the club.');
  if (f.method == RefundMethod.online && !paidOnline) {
    out.add('There is no online payment on this booking to return. Record a refund made at the club instead.');
  }
  if (cents == null || cents < 1) {
    out.add('How much is refunded? Enter an amount above \$0.00.');
  } else if (cents > r.availableCents) {
    out.add('Only ${formatDollars(r.availableCents)} can still be refunded on this booking.');
  } else if (cents > r.suggestedCents && note.length < 3) {
    out.add('This is more than the refund policy suggests (${formatDollars(r.suggestedCents)}): say why.');
  }
  return out;
}

/// The payload of desk_decide_refund.
Map<String, dynamic> decisionParams(String requestId, DecisionForm f) => {
      'p_request': requestId,
      'p_approve': f.approve,
      'p_amount_cents': f.approve ? parseMoney(f.amountText) : null,
      'p_method': f.approve ? f.method!.db : null,
      'p_note': f.note.trim().isEmpty ? null : f.note.trim(),
    };

String decisionMessage(bool approved, RefundMethod? method, int? cents) => !approved
    ? 'Declined. The guest will be told.'
    : method == RefundMethod.club
        ? 'Approved: ${formatDollars(cents ?? 0)}. Pay it back at the club, then record it here.'
        : 'Approved: ${formatDollars(cents ?? 0)}. BottlesUp will return it to the guest\'s card.';

/// What is wrong with the evidence for a refund paid back at the club; null when it can be sent. The evidence is a terminal or receipt reference, a photo of the receipt, or both:
/// the database needs at least one.
String? validateClubReference(String reference, {bool hasPhoto = false}) {
  final r = reference.trim();
  if (r.isEmpty && !hasPhoto) return 'Add the terminal or receipt reference, or a photo of the receipt, as evidence.';
  if (r.length > 200) return 'The reference is too long (200 characters at most).';
  return null;
}

// ---------------------------------------------------------------------------
// Cancelling a booking
// ---------------------------------------------------------------------------

/// What is wrong with the reason for cancelling a booking; null when it can be sent.
String? validateCancelReason(String reason) {
  final r = reason.trim();
  return r.length < 3 || r.length > 500 ? 'Give a reason of 3 to 500 characters.' : null;
}

/// What to tell the manager after the edge function answered. [refundSuggested] = the booking had been paid something.
String cancelledMessage({required bool refundSuggested}) => refundSuggested
    ? 'The booking is cancelled. Money was paid on it, so decide the refund next.'
    : 'The booking is cancelled.';

/// What a failed cancellation says (the cancel-table-booking function). [unknown] = the call may have gone through, so the booking must be looked at before trying again.
String cancelFailure({int? status, String? message}) {
  final m = message?.trim() ?? '';
  switch (status) {
    case null:
      return 'We could not tell whether the booking was cancelled. Look at the booking before trying again.';
    case 401:
      return 'Your sign-in has ended. Sign in again, then look at the booking before trying again.';
    case 403:
      return 'You don\'t have access to cancel this booking.';
    case 404:
      return 'This booking could not be found.';
    case 400:
      if (m.isEmpty) return 'The booking could not be cancelled.';
      return m.endsWith('.') ? m : '$m.';
    default:
      return 'The booking could not be cancelled just now. Look at the booking before trying again.';
  }
}

bool cancelOutcomeUnknown(int? status) => status == null || status >= 500;
