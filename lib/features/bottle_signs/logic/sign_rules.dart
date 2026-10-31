import '../../ops/logic/ops_json.dart';

/// Bottle signs (website repo, 20261116100000_bottle_signs.sql): a short line of text that goes with a bottle to the table ("Happy Birthday"). Who may set one, on which bottles, whether a
/// manager has to approve it first and whether an order may go on without that approval are the database's rules. This file reads what it sends, words it, and checks what a person
/// typed before it is sent.

/// How a club uses signs.
enum SignMode {
  off('off', 'Off', 'Nobody can put a sign on an order.'),
  all('all', 'Every bottle', 'Any bottle on the menu can carry a sign.'),
  selected('selected', 'Chosen bottles', 'Only the bottles you choose below can carry a sign.');

  const SignMode(this.value, this.label, this.explanation);

  final String value;
  final String label;
  final String explanation;

  static SignMode parse(String? v) => SignMode.values.firstWhere((m) => m.value == v, orElse: () => SignMode.off);
}

/// Where a sign stands.
enum SignStatus {
  pendingReview('pending_review', 'Waiting for approval'),
  approved('approved', 'Approved'),
  rejected('rejected', 'Declined');

  const SignStatus(this.value, this.label);

  final String value;
  final String label;

  static SignStatus? parse(String? v) {
    for (final s in SignStatus.values) {
      if (s.value == v) return s;
    }
    return null;
  }
}

/// One bottle of the club's menu and whether it may carry a sign.
class SignBottle {
  const SignBottle({required this.id, required this.name, required this.signEligible, this.size, this.category, this.isAvailable = true});

  final String id;
  final String name;
  final String? size;
  final String? category;
  final bool signEligible;
  final bool isAvailable;

  String get title => size == null ? name : '$name $size';
}

class SignSettings {
  const SignSettings({required this.mode, required this.reviewRequired, required this.bottles});

  final SignMode mode;

  /// A server's sign waits for a manager before the bottle is prepared.
  final bool reviewRequired;
  final List<SignBottle> bottles;

  SignSettings copyWith({SignMode? mode, bool? reviewRequired, List<SignBottle>? bottles}) =>
      SignSettings(mode: mode ?? this.mode, reviewRequired: reviewRequired ?? this.reviewRequired, bottles: bottles ?? this.bottles);
}

SignSettings? parseSignSettings(Map<String, dynamic> r) {
  if (r['mode'] == null) return null;
  final raw = r['bottles'];
  return SignSettings(
    mode: SignMode.parse(opsStr(r, 'mode')),
    reviewRequired: opsBool(r, 'review_required'),
    bottles: [
      if (raw is List)
        for (final b in raw)
          if (b is Map && opsStr(Map<String, dynamic>.from(b), 'id') != null)
            SignBottle(
              id: opsStr(Map<String, dynamic>.from(b), 'id')!,
              name: opsStr(Map<String, dynamic>.from(b), 'name') ?? 'Bottle',
              size: opsStr(Map<String, dynamic>.from(b), 'size'),
              category: opsStr(Map<String, dynamic>.from(b), 'category'),
              signEligible: opsBool(Map<String, dynamic>.from(b), 'sign_eligible'),
              isAvailable: Map<String, dynamic>.from(b)['is_available'] != false,
            ),
    ],
  );
}

/// The sign on one order line, and whether the person may put or change one now.
class LineSign {
  const LineSign({required this.lineId, required this.canSet, required this.reviewRequired, this.text, this.status, this.reviewNote});

  final String lineId;
  final String? text;
  final SignStatus? status;
  final String? reviewNote;

  /// The person may enter or change a sign on this line now (the club allows it for this bottle, and the item has not gone out).
  final bool canSet;
  final bool reviewRequired;

  bool get hasSign => text != null;
  bool get isWaiting => status == SignStatus.pendingReview;
  bool get isDeclined => status == SignStatus.rejected;

  /// With review on, a waiting or declined sign stops the order being prepared or delivered: the database refuses those moves, so they are not offered.
  bool get blocksService => reviewRequired && (isWaiting || isDeclined);

  /// What to tell the person while the sign stops the order, or null when it does not.
  String? get blockMessage => !blocksService
      ? null
      : (isDeclined ? 'The sign was declined. Change the words so a manager can look again.' : 'Waiting for a manager to approve the sign before this is prepared.');
}

LineSign? parseLineSign(Map<String, dynamic> r) {
  final id = opsStr(r, 'line_id');
  if (id == null) return null;
  final text = opsStr(r, 'sign_text');
  return LineSign(
    lineId: id,
    text: text,
    // A sign always has a state; one that arrives without is shown as waiting rather than approved by mistake.
    status: text == null ? null : (SignStatus.parse(opsStr(r, 'sign_status')) ?? SignStatus.pendingReview),
    reviewNote: opsStr(r, 'review_note'),
    canSet: opsBool(r, 'can_set'),
    reviewRequired: opsBool(r, 'review_required'),
  );
}

/// A sign waiting for a manager.
class PendingSign {
  const PendingSign({required this.lineId, required this.bookingId, required this.bottleName, required this.quantity, required this.text, required this.setByName, this.setAt, this.guestName, this.serviceState});

  final String lineId;
  final String bookingId;
  final String bottleName;
  final int quantity;
  final String text;
  final String setByName;
  final DateTime? setAt;
  final String? guestName;
  final String? serviceState;

  String get title => quantity > 1 ? '$quantity × $bottleName' : bottleName;
}

PendingSign? parsePendingSign(Map<String, dynamic> r) {
  final id = opsStr(r, 'line_id');
  final booking = opsStr(r, 'booking_id');
  final text = opsStr(r, 'sign_text');
  if (id == null || booking == null || text == null) return null;
  return PendingSign(
    lineId: id,
    bookingId: booking,
    bottleName: opsStr(r, 'bottle_name') ?? 'Bottle',
    quantity: opsInt(r, 'quantity') < 1 ? 1 : opsInt(r, 'quantity'),
    text: text,
    setByName: opsStr(r, 'set_by_name') ?? 'Staff member',
    setAt: opsTime(r, 'set_at'),
    guestName: opsStr(r, 'guest_name'),
    serviceState: opsStr(r, 'service_status'),
  );
}

/// What came back from setting or reviewing a sign.
class SignChange {
  const SignChange({required this.changed, this.text, this.status});

  final bool changed;
  final String? text;
  final SignStatus? status;
}

SignChange parseSignChange(Object? data) {
  if (data is! Map) return const SignChange(changed: false);
  final m = Map<String, dynamic>.from(data);
  return SignChange(changed: m['changed'] == true, text: opsStr(m, 'sign_text'), status: SignStatus.parse(opsStr(m, 'sign_status')));
}

/// A sign is one line of plain text of at most 40 characters. Empty is fine: it removes the sign. Null when the words are acceptable.
const int maxSignLength = 40;

String? checkSignText(String raw) {
  final t = raw.trim();
  if (t.length > maxSignLength) return 'A sign is at most $maxSignLength characters.';
  if (RegExp(r'[\u0000-\u001F\u007F]').hasMatch(t)) return 'A sign is one line of plain text.';
  return null;
}

/// The reason for declining a sign: 3 to 200 characters. Null when it is acceptable.
String? checkDeclineReason(String raw) {
  final t = raw.trim();
  if (t.length < 3) return 'Say why the sign is declined (at least 3 characters).';
  if (t.length > 200) return 'Keep the reason to 200 characters or fewer.';
  return null;
}

/// The words a person sees after setting a sign, from what the database answered.
String signSavedMessage(SignChange c) {
  if (!c.changed) return 'Nothing changed.';
  if (c.text == null) return 'Sign removed.';
  return c.status == SignStatus.pendingReview ? 'Sign saved. A manager has to approve it before this is prepared.' : 'Sign saved.';
}
