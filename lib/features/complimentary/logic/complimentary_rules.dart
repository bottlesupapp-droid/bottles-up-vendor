import '../../ops/logic/ops_json.dart';

// Complimentary bottle OFFERS with a claim link (website 20261123100000_complimentary_offers.sql; brief section 20). The club's owner or manager offers a bottle to a person by e-mail; the person
// chooses where they are; staff place them at a booking and accept, which makes an ordinary free bottle through the existing free-bottle path (the club's limits and approval rules apply there).
// NOTHING IS SENT yet: the e-mail that carries the link and the public claim page are not built, so an offer waits as "Approved" and staff can place and accept it by hand. The database counts,
// decides who may do what (each row says which steps are open: `actions`) and keeps the record; this file reads it, words it, and checks what was typed.

enum OfferTone { neutral, attention, good, bad }

class OfferStatusInfo {
  const OfferStatusInfo(this.label, this.note, this.tone);

  final String label;
  final String note;
  final OfferTone tone;
}

/// The brief's states, in words. "Approved" is before the link has been sent, which nothing does yet.
OfferStatusInfo offerStatusInfo(String? status) => switch (status) {
  'approved' => const OfferStatusInfo('Approved', 'The link has not been sent: sending is not switched on yet', OfferTone.attention),
  'sent' => const OfferStatusInfo('Sent', 'Waiting for the recipient to open the link', OfferTone.attention),
  'awaiting_location' => const OfferStatusInfo('Awaiting location', 'The link was opened; the recipient has not chosen a table', OfferTone.attention),
  'location_submitted' => const OfferStatusInfo('Location submitted', 'Check the place and choose the booking', OfferTone.attention),
  'accepted' => const OfferStatusInfo('Accepted for service', 'A free bottle is on the booking', OfferTone.good),
  'delivered' => const OfferStatusInfo('Delivered', '', OfferTone.good),
  'expired' => const OfferStatusInfo('Expired', 'It ran out before it was accepted', OfferTone.bad),
  'cancelled' => const OfferStatusInfo('Cancelled', '', OfferTone.neutral),
  _ => const OfferStatusInfo('Unknown', '', OfferTone.neutral),
};

/// What the database says about the free bottle an accepted offer made: waiting for the owner, or applied.
String? concessionNote(String? status) => switch (status) {
  'applied' => 'Free bottle applied',
  'pending' => 'Free bottle waiting for approval (over the club\'s limit)',
  'declined' => 'Free bottle declined',
  'voided' => 'Free bottle taken back',
  _ => null,
};

/// One offer as the club's list shows it.
class OfferRow {
  const OfferRow({
    required this.id,
    required this.bottleName,
    required this.quantity,
    required this.valueCents,
    required this.recipientEmail,
    required this.reason,
    required this.status,
    required this.actions,
    this.bottleSize,
    this.recipientName,
    this.sign,
    this.expiresAt,
    this.createdAt,
    this.createdByName,
    this.locationName,
    this.locationSetBy,
    this.bookingId,
    this.concessionStatus,
    this.deliveredAt,
  });

  final String id;
  final String bottleName;
  final String? bottleSize;
  final int quantity;
  final int valueCents;
  final String recipientEmail;
  final String? recipientName;
  final String reason;
  final String? sign;
  final String status;
  final DateTime? expiresAt;
  final DateTime? createdAt;
  final String? createdByName;
  final String? locationName;
  final String? locationSetBy;
  final String? bookingId;
  final String? concessionStatus;
  final DateTime? deliveredAt;

  /// The steps the database says are open for this offer now: set_location, accept, mark_delivered, cancel.
  final List<String> actions;

  String get item => '$quantity × ${bottleSize == null ? bottleName : '$bottleName · $bottleSize'}';

  /// Who it is for: the name when there is one, always the address.
  String get recipient => recipientName == null ? recipientEmail : '$recipientName · $recipientEmail';

  bool can(String action) => actions.contains(action);
}

OfferRow? parseOfferRow(Map<String, dynamic> r) {
  final id = opsStr(r, 'offer_id');
  final status = opsStr(r, 'status');
  if (id == null || status == null) return null;
  return OfferRow(
    id: id,
    bottleName: opsStr(r, 'bottle_name') ?? 'Bottle',
    bottleSize: opsStr(r, 'bottle_size'),
    quantity: opsInt(r, 'quantity'),
    valueCents: opsInt(r, 'value_cents'),
    recipientEmail: opsStr(r, 'recipient_email') ?? '',
    recipientName: opsStr(r, 'recipient_name'),
    reason: opsStr(r, 'reason') ?? '',
    sign: opsStr(r, 'sign_text'),
    status: status,
    expiresAt: opsTime(r, 'expires_at'),
    createdAt: opsTime(r, 'created_at'),
    createdByName: opsStr(r, 'created_by_name'),
    locationName: opsStr(r, 'location_table_name'),
    locationSetBy: opsStr(r, 'location_set_by'),
    bookingId: opsStr(r, 'booking_id'),
    concessionStatus: opsStr(r, 'concession_status'),
    deliveredAt: opsTime(r, 'delivered_at'),
    actions: [
      if (r['actions'] is List)
        for (final a in r['actions'] as List) '$a',
    ],
  );
}

/// A table of the club, by its label, for placing a recipient by hand.
class OfferTable {
  const OfferTable({required this.id, required this.name, this.floor});

  final String id;
  final String name;
  final String? floor;

  String get label => floor == null ? name : '$name · $floor';
}

OfferTable? parseOfferTable(Map<String, dynamic> r) {
  final id = opsStr(r, 'table_id');
  if (id == null) return null;
  return OfferTable(id: id, name: opsStr(r, 'name') ?? 'Table', floor: opsStr(r, 'floor_label'));
}

/// A booking a recipient could be placed at.
class OfferBooking {
  const OfferBooking({required this.id, required this.code, required this.guestName, required this.tableName, required this.guestCount});

  final String id;
  final String code;
  final String guestName;
  final String tableName;
  final int guestCount;

  String get label => '$guestName · $tableName · $guestCount ${guestCount == 1 ? 'guest' : 'guests'} · $code';
}

OfferBooking? parseOfferBooking(Map<String, dynamic> r) {
  final id = opsStr(r, 'booking_id');
  if (id == null) return null;
  return OfferBooking(
    id: id,
    code: opsStr(r, 'confirmation_code') ?? '',
    guestName: opsStr(r, 'guest_name') ?? 'Guest',
    tableName: opsStr(r, 'table_name') ?? 'Table',
    guestCount: opsInt(r, 'guest_count'),
  );
}

/// What accepting an offer made.
class AcceptOutcome {
  const AcceptOutcome({required this.concessionStatus});

  /// 'applied' or 'pending' (over the club's limit: it waits for the owner, as a free bottle at a table would).
  final String? concessionStatus;

  bool get pending => concessionStatus == 'pending';
}

AcceptOutcome? parseAcceptOutcome(dynamic data) {
  if (data is! Map) return null;
  return AcceptOutcome(concessionStatus: opsStr(Map<String, dynamic>.from(data), 'concession_status'));
}

/// The hours a link can last, as the database allows (1 hour to 7 days), and the choices offered.
const List<({int hours, String label})> expiryChoices = [(hours: 6, label: '6 hours'), (hours: 24, label: '24 hours'), (hours: 72, label: '3 days'), (hours: 168, label: '7 days')];

const int defaultExpiryHours = 24;

/// What was typed for a new offer, checked the way the database will check it.
class OfferDraft {
  const OfferDraft({required this.bottleId, required this.quantity, required this.email, required this.reason, this.name, this.sign, this.expiresHours = defaultExpiryHours});

  final String bottleId;
  final int quantity;
  final String email;
  final String? name;
  final String reason;
  final String? sign;
  final int expiresHours;
}

final RegExp _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

({OfferDraft? draft, String? error}) checkOfferForm({
  required String? bottleId,
  required String quantityText,
  required String email,
  required String name,
  required String reason,
  required String sign,
  required int expiresHours,
}) {
  if (bottleId == null || bottleId.isEmpty) return (draft: null, error: 'Choose the bottle.');
  final qty = int.tryParse(quantityText.trim());
  if (qty == null || qty < 1 || qty > 12) return (draft: null, error: 'Choose from 1 to 12 bottles.');
  final e = email.trim();
  if (e.isEmpty || e.length > 254 || !_email.hasMatch(e)) return (draft: null, error: 'Enter the e-mail address the link is for.');
  final n = name.trim();
  if (n.length > 60) return (draft: null, error: 'Keep the name to 60 characters or fewer.');
  final r = reason.trim();
  if (r.length < 3) return (draft: null, error: 'Say why, in at least 3 characters. It is kept with the offer.');
  if (r.length > 300) return (draft: null, error: 'Keep the reason to 300 characters or fewer.');
  final s = sign.trim();
  if (s.length > 40 || s.contains('\n')) return (draft: null, error: 'Keep the sign to 40 characters, on one line.');
  if (expiresHours < 1 || expiresHours > 168) return (draft: null, error: 'The link can last from 1 hour to 7 days.');
  return (draft: OfferDraft(bottleId: bottleId, quantity: qty, email: e, name: n.isEmpty ? null : n, reason: r, sign: s.isEmpty ? null : s, expiresHours: expiresHours), error: null);
}

/// A reason for cancelling.
String? checkCancelReason(String text) {
  final t = text.trim();
  if (t.length < 3) return 'Say why, in at least 3 characters.';
  if (t.length > 300) return 'Keep it to 300 characters or fewer.';
  return null;
}

/// The note on the page: what is and is not built, so nobody thinks a link has gone out.
const String claimNote =
    'An offer is a bottle you give to someone with no table yet. They get a link, choose where they are, and you place them at their booking: that makes an ordinary free bottle, under the club\'s own limits. The e-mail with the link is not switched on yet, so nothing is sent from here: place and accept an offer by hand.';
