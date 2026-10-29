import '../../owner/logic/setup_forms.dart' show formatDollars, parseMoney, parseWhole;
import '../../table_service/logic/bottle_orders_rules.dart' show MenuBottle;

// Discounts and free bottles given by the club's own people (developer brief 15 Oct 2026, section 21; the client's answer of 20 Oct: the owner decides the rules and limits, a
// manager approves within them, a server only uses what is approved, and until limits are set staff cannot give their own; the system records who approved it and updates stock).
// Pure Dart, tested without a screen. Every check mirrors the database function that finally decides (website repo, 20261024100000_staff_discounts_and_complimentary.sql), so the
// form says what is wrong in plain words before anything is sent and the database still refuses whatever gets past it.

int? _int(Object? v) => v is num ? v.toInt() : int.tryParse('$v');
String? _text(Object? v) {
  final s = v?.toString().trim();
  return s == null || s.isEmpty ? null : s;
}

// ---------------------------------------------------------------------------
// What the caller may give on one table
// ---------------------------------------------------------------------------

enum GiverRole {
  server('server', 'server'),
  manager('manager', 'manager'),
  owner('owner', 'owner');

  const GiverRole(this.db, this.label);

  final String db;
  final String label;

  static GiverRole? fromDb(String? v) {
    for (final r in values) {
      if (r.db == v) return r;
    }
    return null;
  }

  /// Who decides what is above this person's own limit.
  String get approver => switch (this) {
        GiverRole.server => 'a manager',
        GiverRole.manager => 'the owner',
        GiverRole.owner => 'the owner',
      };
}

/// The caller's limits tonight on this table (desk_concession_limits).
class ConcessionLimits {
  const ConcessionLimits({
    required this.role,
    required this.limitsSet,
    required this.maxPercent,
    this.freeBottlesAllowed,
    required this.freeBottlesUsed,
    required this.allowStacking,
    required this.bottleSubtotalCents,
    required this.balanceDueCents,
    required this.discountedCents,
  });

  final GiverRole role;

  /// The owner has set limits for this club (an owner needs none).
  final bool limitsSet;

  /// The biggest discount this person may give on their own, in percent of the table's bottles.
  final int maxPercent;

  /// Free bottles this person may give tonight; null = no limit (the owner).
  final int? freeBottlesAllowed;
  final int freeBottlesUsed;
  final bool allowStacking;
  final int bottleSubtotalCents;
  final int balanceDueCents;
  final int discountedCents;

  /// Free bottles still allowed tonight without asking; null = no limit.
  int? get freeLeft => freeBottlesAllowed == null ? null : (freeBottlesAllowed! - freeBottlesUsed < 0 ? 0 : freeBottlesAllowed! - freeBottlesUsed);

  bool get isOwner => role == GiverRole.owner;
}

ConcessionLimits? parseConcessionLimits(dynamic data) {
  if (data is! Map) return null;
  final r = Map<String, dynamic>.from(data);
  final role = GiverRole.fromDb(_text(r['role']));
  if (role == null) return null;
  return ConcessionLimits(
    role: role,
    limitsSet: r['limits_set'] == true,
    maxPercent: _int(r['max_percent']) ?? 0,
    freeBottlesAllowed: _int(r['free_bottles_allowed']),
    freeBottlesUsed: _int(r['free_bottles_used']) ?? 0,
    allowStacking: r['allow_stacking'] == true,
    bottleSubtotalCents: _int(r['bottle_subtotal_cents']) ?? 0,
    balanceDueCents: _int(r['balance_due_cents']) ?? 0,
    discountedCents: _int(r['discounted_cents']) ?? 0,
  );
}

/// What the caller may do tonight, in plain words.
String limitsLine(ConcessionLimits l) {
  if (l.isOwner) return 'You are the owner: you can give any discount or free bottle.';
  if (!l.limitsSet) return 'The owner has not set discount limits for this club yet, so nothing can be given.';
  final free = l.freeBottlesAllowed ?? 0;
  final left = l.freeLeft ?? 0;
  return 'You may give a discount up to ${l.maxPercent}% on your own, and $free free ${free == 1 ? 'bottle' : 'bottles'} tonight ($left left). Anything more waits for ${l.role.approver}.';
}

// ---------------------------------------------------------------------------
// What has been given
// ---------------------------------------------------------------------------

enum ConcessionStatus {
  applied('applied', 'Applied'),
  pending('pending', 'Waiting for approval'),
  declined('declined', 'Declined'),
  voided('voided', 'Taken back');

  const ConcessionStatus(this.db, this.label);

  final String db;
  final String label;

  static ConcessionStatus? fromDb(String? v) {
    for (final s in values) {
      if (s.db == v) return s;
    }
    return null;
  }
}

/// A discount or free bottle on one table (desk_booking_concessions).
class Concession {
  const Concession({
    required this.id,
    required this.isDiscount,
    this.percent,
    required this.amountCents,
    this.bottleName,
    this.quantity,
    required this.status,
    required this.reason,
    required this.requestedBy,
    required this.requestedRole,
    this.decidedBy,
    this.decisionNote,
    required this.createdAt,
  });

  final String id;
  final bool isDiscount;
  final int? percent;
  final int amountCents;
  final String? bottleName;
  final int? quantity;
  final ConcessionStatus status;
  final String reason;
  final String requestedBy;
  final String requestedRole;
  final String? decidedBy;
  final String? decisionNote;
  final DateTime createdAt;

  /// An applied one can be taken back (by a manager or the owner).
  bool get canTakeBack => status == ConcessionStatus.applied;
}

Concession? parseConcession(Map<String, dynamic> r) {
  final id = _text(r['concession_id']);
  final kind = _text(r['kind']);
  final status = ConcessionStatus.fromDb(_text(r['status']));
  final amount = _int(r['amount_cents']);
  final created = DateTime.tryParse(r['created_at']?.toString() ?? '');
  if (id == null || (kind != 'discount' && kind != 'free_bottle') || status == null || amount == null || created == null) return null;
  return Concession(
    id: id,
    isDiscount: kind == 'discount',
    percent: _int(r['percent']),
    amountCents: amount,
    bottleName: _text(r['bottle_name']),
    quantity: _int(r['quantity']),
    status: status,
    reason: _text(r['reason']) ?? '',
    requestedBy: _text(r['requested_by_name']) ?? 'Staff member',
    requestedRole: _text(r['requested_role']) ?? '',
    decidedBy: _text(r['decided_by_name']),
    decisionNote: _text(r['decision_note']),
    createdAt: created.toLocal(),
  );
}

/// "10% discount: \$25.00 off", "\$20.00 discount", or "2 × Patron free".
String concessionTitle({required bool isDiscount, int? percent, required int amountCents, String? bottleName, int? quantity}) {
  if (!isDiscount) return '${quantity ?? 1} × ${bottleName ?? 'bottle'} free';
  return percent == null ? '${formatDollars(amountCents)} discount' : '$percent% discount: ${formatDollars(amountCents)} off';
}

String concessionLine(Concession c) => concessionTitle(isDiscount: c.isDiscount, percent: c.percent, amountCents: c.amountCents, bottleName: c.bottleName, quantity: c.quantity);

/// Who asked and who approved, in a sentence.
String concessionWho(Concession c) {
  final asked = 'Asked by ${c.requestedBy}${c.requestedRole.isEmpty ? '' : ' (${c.requestedRole})'}';
  return switch (c.status) {
    ConcessionStatus.applied => c.decidedBy == null ? '$asked, within their own limit' : '$asked, approved by ${c.decidedBy}',
    ConcessionStatus.pending => '$asked, waiting for approval',
    ConcessionStatus.declined => '$asked, declined${c.decidedBy == null ? '' : ' by ${c.decidedBy}'}${c.decisionNote == null ? '' : ': ${c.decisionNote}'}',
    ConcessionStatus.voided => '$asked, taken back${c.decisionNote == null ? '' : ': ${c.decisionNote}'}',
  };
}

// ---------------------------------------------------------------------------
// Giving a discount
// ---------------------------------------------------------------------------

enum DiscountKind {
  percent('percent', 'Percent'),
  amount('amount', 'Amount');

  const DiscountKind(this.db, this.label);

  final String db;
  final String label;
}

class DiscountForm {
  const DiscountForm({required this.kind, this.valueText = '', this.reason = ''});

  final DiscountKind kind;
  final String valueText;
  final String reason;
}

/// The discount in cents for what was typed, or null when it cannot be worked out.
int? discountCents(DiscountForm f, int baseCents) {
  if (f.kind == DiscountKind.percent) {
    final p = parseWhole(f.valueText);
    return p == null || p < 1 || p > 100 ? null : (baseCents * p / 100).floor();
  }
  return parseMoney(f.valueText);
}

/// The share of the table's bottles a discount of [cents] is, rounded up (the way the database counts it against a person's limit).
int discountPercentOf(int cents, int baseCents) => baseCents <= 0 ? 0 : (cents * 100 / baseCents).ceil();

/// What is wrong with a discount, in plain words. Empty means it can be sent. [existing] is what the table already carries.
List<String> validateDiscount(DiscountForm f, ConcessionLimits l, List<Concession> existing) {
  final out = <String>[];
  if (!l.isOwner && !l.limitsSet) {
    return const ['The owner has not set discount limits for this club yet, so nothing can be given.'];
  }
  final base = l.bottleSubtotalCents;
  if (base <= 0) {
    out.add('There are no bottles on this table to discount.');
  } else if (f.kind == DiscountKind.percent) {
    final p = parseWhole(f.valueText);
    if (p == null || p < 1 || p > 100) {
      out.add('A percent discount is between 1 and 100.');
    } else if ((base * p / 100).floor() < 1) {
      out.add('That discount is less than one cent.');
    }
  } else {
    final cents = parseMoney(f.valueText);
    if (cents == null || cents < 1) {
      out.add('How much is the discount? Enter an amount above \$0.00.');
    } else if (cents > base) {
      out.add('A discount cannot be more than the table\'s bottles (${formatDollars(base)}).');
    }
  }
  final cents = base <= 0 ? null : discountCents(f, base);
  if (out.isEmpty && cents != null && cents > l.balanceDueCents) {
    out.add('A discount of ${formatDollars(cents)} is more than this table still owes (${formatDollars(l.balanceDueCents)}).');
  }
  if (out.isEmpty && !l.allowStacking && existing.any((c) => c.isDiscount && (c.status == ConcessionStatus.applied || c.status == ConcessionStatus.pending))) {
    out.add('This table already has a discount: discounts do not combine at this club.');
  }
  final reason = f.reason.trim();
  if (reason.length < 3 || reason.length > 300) out.add('Give a reason of 3 to 300 characters.');
  return out;
}

Map<String, dynamic> discountParams(String bookingId, DiscountForm f, int baseCents) => {
      'p_booking': bookingId,
      'p_kind': f.kind.db,
      'p_value': f.kind == DiscountKind.percent ? parseWhole(f.valueText) : parseMoney(f.valueText),
      'p_reason': f.reason.trim(),
    };

/// What will happen to a discount of [cents], before it is sent: applied at once within the person's own limit, or waiting for someone.
String discountPreview(ConcessionLimits l, int cents) {
  final pct = discountPercentOf(cents, l.bottleSubtotalCents);
  if (l.isOwner || pct <= l.maxPercent) return '${formatDollars(cents)} off ($pct% of the bottles): applied at once.';
  return '${formatDollars(cents)} off ($pct% of the bottles) is above your limit of ${l.maxPercent}%: it waits for ${l.role.approver} to approve.';
}

// ---------------------------------------------------------------------------
// Giving a free bottle
// ---------------------------------------------------------------------------

class FreeBottleForm {
  const FreeBottleForm({this.bottle, this.quantity = 1, this.reason = ''});

  final MenuBottle? bottle;
  final int quantity;
  final String reason;
}

const int maxFreeBottles = 100;

/// What is wrong with a free bottle, in plain words. Empty means it can be sent.
List<String> validateFreeBottle(FreeBottleForm f, ConcessionLimits l) {
  final out = <String>[];
  if (!l.isOwner && !l.limitsSet) return const ['The owner has not set limits for free bottles at this club yet, so nothing can be given.'];
  final b = f.bottle;
  if (b == null) {
    out.add('Choose the bottle.');
  } else if (b.soldOutByCount) {
    out.add('${b.title} is sold out.');
  } else if (b.leftCount != null && f.quantity > b.leftCount!) {
    out.add('Only ${b.leftCount} of ${b.title} ${b.leftCount == 1 ? 'is' : 'are'} left.');
  }
  if (f.quantity < 1 || f.quantity > maxFreeBottles) out.add('How many bottles? Between 1 and $maxFreeBottles.');
  final reason = f.reason.trim();
  if (reason.length < 3 || reason.length > 300) out.add('Give a reason of 3 to 300 characters.');
  return out;
}

Map<String, dynamic> freeBottleParams(String bookingId, FreeBottleForm f) => {
      'p_booking': bookingId,
      'p_bottle': f.bottle!.id,
      'p_quantity': f.quantity,
      'p_reason': f.reason.trim(),
    };

/// What will happen to a free bottle request, before it is sent.
String freeBottlePreview(ConcessionLimits l, int quantity) {
  final left = l.freeLeft;
  if (left == null || quantity <= left) {
    return left == null ? 'Applied at once.' : 'Within your allowance tonight ($left left): applied at once.';
  }
  return 'More than your allowance tonight ($left left): it waits for ${l.role.approver} to approve.';
}

// ---------------------------------------------------------------------------
// The answer to a request
// ---------------------------------------------------------------------------

class ConcessionResult {
  const ConcessionResult({required this.id, required this.applied, this.amountCents, this.percent, this.valueCents});

  final String id;
  final bool applied;
  final int? amountCents;
  final int? percent;
  final int? valueCents;
}

ConcessionResult? parseConcessionResult(dynamic data) {
  if (data is! Map) return null;
  final id = _text(data['id']);
  final status = _text(data['status']);
  if (id == null || (status != 'applied' && status != 'pending')) return null;
  return ConcessionResult(id: id, applied: status == 'applied', amountCents: _int(data['amount_cents']), percent: _int(data['percent']), valueCents: _int(data['value_cents']));
}

String discountGivenMessage(ConcessionResult r, ConcessionLimits l) {
  final off = formatDollars(r.amountCents ?? 0);
  return r.applied ? 'Discount applied: $off off. The table now owes less.' : 'Waiting for approval: $off off. ${l.role.approver[0].toUpperCase()}${l.role.approver.substring(1)} will decide.';
}

String freeBottleGivenMessage(ConcessionResult r, ConcessionLimits l, String name, int quantity) => r.applied
    ? '$quantity × $name added at no charge. It is served like any other order and counts against stock, not sales.'
    : 'Waiting for approval: $quantity × $name. ${l.role.approver[0].toUpperCase()}${l.role.approver.substring(1)} will decide.';

// ---------------------------------------------------------------------------
// What waits for approval
// ---------------------------------------------------------------------------

class PendingConcession {
  const PendingConcession({
    required this.id,
    required this.bookingId,
    this.code,
    required this.guestName,
    required this.tableName,
    required this.isDiscount,
    this.percent,
    required this.amountCents,
    this.bottleName,
    this.quantity,
    required this.reason,
    required this.requestedBy,
    required this.requestedRole,
    required this.createdAt,
    required this.canDecide,
  });

  final String id;
  final String bookingId;
  final String? code;
  final String guestName;
  final String tableName;
  final bool isDiscount;
  final int? percent;
  final int amountCents;
  final String? bottleName;
  final int? quantity;
  final String reason;
  final String requestedBy;
  final String requestedRole;
  final DateTime createdAt;

  /// The caller may decide it (never their own; a manager only within the manager's limit; the owner anything).
  final bool canDecide;

  String get title => concessionTitle(isDiscount: isDiscount, percent: percent, amountCents: amountCents, bottleName: bottleName, quantity: quantity);
}

PendingConcession? parsePending(Map<String, dynamic> r) {
  final id = _text(r['concession_id']);
  final booking = _text(r['booking_id']);
  final kind = _text(r['kind']);
  final amount = _int(r['amount_cents']);
  final created = DateTime.tryParse(r['created_at']?.toString() ?? '');
  if (id == null || booking == null || (kind != 'discount' && kind != 'free_bottle') || amount == null || created == null) return null;
  return PendingConcession(
    id: id,
    bookingId: booking,
    code: _text(r['confirmation_code']),
    guestName: _text(r['guest_name']) ?? 'Guest',
    tableName: _text(r['table_name']) ?? 'Table',
    isDiscount: kind == 'discount',
    percent: _int(r['percent']),
    amountCents: amount,
    bottleName: _text(r['bottle_name']),
    quantity: _int(r['quantity']),
    reason: _text(r['reason']) ?? '',
    requestedBy: _text(r['requested_by_name']) ?? 'Staff member',
    requestedRole: _text(r['requested_role']) ?? '',
    createdAt: created.toLocal(),
    canDecide: r['can_decide'] == true,
  );
}

/// Why a waiting request cannot be decided by this person, or null when they can.
String? cannotDecideWhy(PendingConcession p) => p.canDecide ? null : 'You cannot decide this one: it is your own, or it is above what a manager may approve. Another manager or the owner decides.';

/// What is wrong with a decision, in plain words. Declining needs a reason the person can be told.
String? validateConcessionDecision({required bool approve, required String note}) {
  final n = note.trim();
  if (n.length > 300) return 'The note can be up to 300 characters.';
  if (!approve && n.length < 3) return 'Say why it is declined, so the person can be told.';
  return null;
}

Map<String, dynamic> decisionParams(String id, bool approve, String note) => {'p_id': id, 'p_approve': approve, 'p_note': note.trim().isEmpty ? null : note.trim()};

String? validateTakeBackNote(String note) {
  final n = note.trim();
  if (n.length < 3) return 'Say why it is taken back.';
  if (n.length > 300) return 'The note can be up to 300 characters.';
  return null;
}

// ---------------------------------------------------------------------------
// The limits (the owner sets them)
// ---------------------------------------------------------------------------

class DiscountLimits {
  const DiscountLimits({
    required this.hasLimits,
    required this.serverMaxPercent,
    required this.managerMaxPercent,
    required this.serverFreeBottles,
    required this.managerFreeBottles,
    required this.allowStacking,
  });

  final bool hasLimits;
  final int serverMaxPercent;
  final int managerMaxPercent;
  final int serverFreeBottles;
  final int managerFreeBottles;
  final bool allowStacking;
}

DiscountLimits? parseDiscountLimits(Map<String, dynamic> r) {
  if (!r.containsKey('has_limits')) return null;
  return DiscountLimits(
    hasLimits: r['has_limits'] == true,
    serverMaxPercent: _int(r['server_max_percent']) ?? 0,
    managerMaxPercent: _int(r['manager_max_percent']) ?? 0,
    serverFreeBottles: _int(r['server_free_bottles_per_night']) ?? 0,
    managerFreeBottles: _int(r['manager_free_bottles_per_night']) ?? 0,
    allowStacking: r['allow_stacking'] == true,
  );
}

class LimitsForm {
  const LimitsForm({this.serverPercent = '0', this.managerPercent = '0', this.serverBottles = '0', this.managerBottles = '0', this.allowStacking = false});

  final String serverPercent;
  final String managerPercent;
  final String serverBottles;
  final String managerBottles;
  final bool allowStacking;
}

LimitsForm limitsFormFrom(DiscountLimits? l) => l == null
    ? const LimitsForm()
    : LimitsForm(
        serverPercent: '${l.serverMaxPercent}',
        managerPercent: '${l.managerMaxPercent}',
        serverBottles: '${l.serverFreeBottles}',
        managerBottles: '${l.managerFreeBottles}',
        allowStacking: l.allowStacking,
      );

/// What is wrong with the limits, in plain words. Empty means they can be saved.
List<String> validateLimits(LimitsForm f) {
  final out = <String>[];
  final sp = parseWhole(f.serverPercent);
  final mp = parseWhole(f.managerPercent);
  final sb = parseWhole(f.serverBottles);
  final mb = parseWhole(f.managerBottles);
  if (sp == null || sp > 100) out.add('A server\'s discount limit is a whole number from 0 to 100.');
  if (mp == null || mp > 100) out.add('A manager\'s discount limit is a whole number from 0 to 100.');
  if (sb == null || sb > 100) out.add('A server\'s free bottles a night is a whole number from 0 to 100.');
  if (mb == null || mb > 500) out.add('The managers\' free bottles a night is a whole number from 0 to 500.');
  if (out.isNotEmpty) return out;
  if (sp! > mp!) out.add('A server cannot be allowed a bigger discount than a manager.');
  if (sb! > mb!) out.add('A server cannot be allowed more free bottles a night than the managers\' pool.');
  return out;
}

/// All five keys every time (a key that is left out keeps its value).
Map<String, dynamic> limitsPayload(LimitsForm f) => {
      'server_max_percent': parseWhole(f.serverPercent),
      'manager_max_percent': parseWhole(f.managerPercent),
      'server_free_bottles_per_night': parseWhole(f.serverBottles),
      'manager_free_bottles_per_night': parseWhole(f.managerBottles),
      'allow_stacking': f.allowStacking,
    };

bool limitsChanged(DiscountLimits? saved, LimitsForm f) {
  if (saved == null || !saved.hasLimits) return true;
  final now = limitsFormFrom(saved);
  return now.serverPercent != f.serverPercent.trim() ||
      now.managerPercent != f.managerPercent.trim() ||
      now.serverBottles != f.serverBottles.trim() ||
      now.managerBottles != f.managerBottles.trim() ||
      now.allowStacking != f.allowStacking;
}

/// The limits in words.
List<String> limitsWords(DiscountLimits l) => !l.hasLimits
    ? const ['No limits are set, so servers and managers cannot give discounts or free bottles of their own. The owner can.']
    : [
        'A server may give up to ${l.serverMaxPercent}% off and ${l.serverFreeBottles} free ${l.serverFreeBottles == 1 ? 'bottle' : 'bottles'} a night.',
        'A manager may give up to ${l.managerMaxPercent}% off, and the managers share ${l.managerFreeBottles} free ${l.managerFreeBottles == 1 ? 'bottle' : 'bottles'} a night.',
        l.allowStacking ? 'More than one discount may be on a table.' : 'Only one discount may be on a table.',
        'Anything above a limit waits for a manager or the owner to approve.',
      ];
