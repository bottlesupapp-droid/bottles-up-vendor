// Bottle orders, payments taken at the club, checking them, and the manager's "Tonight" numbers (Phase 2 brief, sections 6, 13, 14 and
// 15). Pure Dart, tested without a screen. The database decides who may do what (website repo, 20261014120000_desk_orders.sql and
// 20261014130000_desk_payments.sql); this file knows the words, the shapes of the answers, which buttons make sense and what a payment
// form must hold, so the screen never offers a move the database would refuse. A test reads the SQL (when the website repo is checked
// out beside this app) and fails if the lists, limits or sentences differ.

import '../../owner/logic/setup_forms.dart' show formatDollars, parseMoney;
import '../../server_desk/logic/server_desk_rules.dart' show AssignedTable;

String? _text(Object? v) => v is String && v.trim().isNotEmpty ? v : null;
int _int(Object? v) =>
    v is int ? v : (v is num && v == v.roundToDouble() ? v.toInt() : 0);
int? _intOrNull(Object? v) =>
    v is int ? v : (v is num && v == v.roundToDouble() ? v.toInt() : null);
DateTime? _time(Object? v) => v is String ? DateTime.tryParse(v) : null;

// ---------------------------------------------------------------------------
// Where an order stands, and how it is paid
// ---------------------------------------------------------------------------

/// The five service states the database allows on a bottle line. The brief names Submitted / Accepted / Preparing / On the way /
/// Delivered; the database has no separate "accepted", and has "ready" between preparing and on the way, so the words are these.
enum ServiceState {
  awaitingPrep('awaiting_prep', 'New', 'Back to New'),
  preparing('preparing', 'Preparing', 'Start preparing'),
  ready('ready', 'Ready', 'Mark ready'),
  pickedUp('picked_up', 'On the way', 'On the way'),
  served('served', 'Delivered', 'Delivered');

  const ServiceState(this.value, this.label, this.moveLabel);

  /// As the database stores it.
  final String value;
  final String label;

  /// What the button that moves an order INTO this state says.
  final String moveLabel;

  /// The step after this one, or null once delivered.
  ServiceState? get next =>
      index + 1 < values.length ? values[index + 1] : null;

  static ServiceState? fromDb(Object? v) {
    for (final s in values) {
      if (s.value == v) return s;
    }
    return null;
  }
}

/// How an order line is paid. Independent of where it stands in service.
enum LinePayment {
  paid('paid', 'Paid'),
  dueAtVenue('due_at_venue', 'Pay at venue'),
  pendingPayment('pending_payment', 'Payment pending');

  const LinePayment(this.value, this.label);

  final String value;
  final String label;

  static LinePayment? fromDb(Object? v) {
    for (final p in values) {
      if (p.value == v) return p;
    }
    return null;
  }
}

// ---------------------------------------------------------------------------
// An order line, as the database lists it
// ---------------------------------------------------------------------------

/// One bottle line. [OrderLine.fromOrders] is a row of a night's list (it carries the table); [OrderLine.fromTable] is a row of one
/// table's sheet (it carries the unit price and any cancellation, and the table is known from the screen).
class OrderLine {
  const OrderLine({
    required this.lineId,
    required this.bookingId,
    required this.bottleName,
    required this.size,
    required this.quantity,
    required this.unitPriceCents,
    required this.lineTotalCents,
    required this.isAddon,
    required this.payment,
    required this.state,
    required this.orderedAt,
    this.cancelledAt,
    this.cancellationReason,
    this.confirmationCode,
    this.customerName,
    this.tableName,
    this.guestCount,
    this.checkedInAt,
    this.balanceDueCents,
    this.serverMembershipId,
    this.serverIsMe = false,
  });

  final String lineId;
  final String? bookingId;
  final String bottleName;
  final String? size;
  final int quantity;

  /// Only on a table's own sheet.
  final int? unitPriceCents;
  final int lineTotalCents;
  final bool isAddon;
  final LinePayment payment;
  final ServiceState state;
  final DateTime orderedAt;
  final DateTime? cancelledAt;
  final String? cancellationReason;

  // Only on a night's list:
  final String? confirmationCode;
  final String? customerName;
  final String? tableName;
  final int? guestCount;
  final DateTime? checkedInAt;

  /// What the whole table still owes (not just this line).
  final int? balanceDueCents;
  final String? serverMembershipId;
  final bool serverIsMe;

  bool get cancelled => cancelledAt != null;
  bool get delivered => state == ServiceState.served;

  /// "2 × Patron 750ml".
  String get title => '$quantity × $bottleName${size == null ? '' : ' $size'}';
}

/// One `desk_orders` row. A row without an id, with an unknown state or payment, or without a time is dropped rather than guessed at:
/// showing an unknown state as New would hide that it needs attention somewhere else.
OrderLine? parseOrderLine(Map<String, dynamic> r) {
  final id = r['line_id'];
  final state = ServiceState.fromDb(r['service_status']);
  final payment = LinePayment.fromDb(r['payment_status']);
  final at = _time(r['ordered_at']);
  if (id is! String ||
      id.isEmpty ||
      state == null ||
      payment == null ||
      at == null) {
    return null;
  }
  final booking = r['booking_id'];
  return OrderLine(
    lineId: id,
    bookingId: booking is String && booking.isNotEmpty ? booking : null,
    bottleName: _text(r['bottle_name']) ?? 'Bottle',
    size: _text(r['size']),
    quantity: _int(r['quantity']),
    unitPriceCents: null,
    lineTotalCents: _int(r['line_total_cents']),
    isAddon: r['is_addon'] == true,
    payment: payment,
    state: state,
    orderedAt: at,
    confirmationCode: _text(r['confirmation_code']),
    customerName: _text(r['customer_name']),
    tableName: _text(r['table_name']),
    guestCount: _intOrNull(r['guest_count']),
    checkedInAt: _time(r['checked_in_at']),
    balanceDueCents: _intOrNull(r['balance_due_cents']),
    serverMembershipId: _text(r['server_membership_id']),
    serverIsMe: r['server_is_me'] == true,
  );
}

/// One `desk_booking_orders` row (one table's sheet).
OrderLine? parseTableLine(
  Map<String, dynamic> r, {
  required String bookingId,
  int? balanceDueCents,
}) {
  final id = r['line_id'];
  final state = ServiceState.fromDb(r['service_status']);
  final payment = LinePayment.fromDb(r['payment_status']);
  final at = _time(r['ordered_at']);
  if (id is! String ||
      id.isEmpty ||
      state == null ||
      payment == null ||
      at == null) {
    return null;
  }
  return OrderLine(
    lineId: id,
    bookingId: bookingId,
    bottleName: _text(r['bottle_name']) ?? 'Bottle',
    size: _text(r['size']),
    quantity: _int(r['quantity']),
    unitPriceCents: _intOrNull(r['unit_price_cents']),
    lineTotalCents: _int(r['line_total_cents']),
    isAddon: r['is_addon'] == true,
    payment: payment,
    state: state,
    orderedAt: at,
    cancelledAt: _time(r['cancelled_at']),
    cancellationReason: _text(r['cancellation_reason']),
    balanceDueCents: balanceDueCents,
  );
}

// ---------------------------------------------------------------------------
// Filters (brief section 13: "new, needs payment, preparing, on the way, delivered")
// ---------------------------------------------------------------------------

/// "Needs attention" is in the brief too, but it means orders left waiting too long, and the client has not yet said how long. It is
/// not guessed at here: the list shows how long each order has waited, longest first.
enum OrderFilter {
  all('All'),
  fresh('New'),
  needsPayment('Needs payment'),
  preparing('Preparing'),
  onTheWay('On the way'),
  delivered('Delivered');

  const OrderFilter(this.label);

  final String label;
}

bool orderMatches(OrderFilter f, OrderLine l) => switch (f) {
  OrderFilter.all => true,
  OrderFilter.fresh => l.state == ServiceState.awaitingPrep,
  OrderFilter.needsPayment =>
    l.payment == LinePayment.dueAtVenue && (l.balanceDueCents ?? 0) > 0,
  OrderFilter.preparing =>
    l.state == ServiceState.preparing || l.state == ServiceState.ready,
  OrderFilter.onTheWay => l.state == ServiceState.pickedUp,
  OrderFilter.delivered => l.state == ServiceState.served,
};

Map<OrderFilter, int> filterCounts(Iterable<OrderLine> lines) => {
  for (final f in OrderFilter.values)
    f: lines.where((l) => orderMatches(f, l)).length,
};

// ---------------------------------------------------------------------------
// Which moves to offer
// ---------------------------------------------------------------------------

/// Why an order cannot be delivered yet, or null. An item to be paid at the venue is not handed over while its table still owes
/// money. (The database checks this and also that a payment was recorded; it is the screen's job to say so before the tap.)
String? deliveryBlock(OrderLine l) {
  final owed = l.balanceDueCents ?? 0;
  if (l.payment == LinePayment.dueAtVenue && owed > 0) {
    return 'The table still owes ${formatDollars(owed)}. Take payment first.';
  }
  return null;
}

/// The states this order can be moved to by this person, never the one it is in. A server cannot take a delivered item back (only a
/// manager can); nothing can be done to a cancelled line.
List<ServiceState> moveTargets(OrderLine l, {required bool manager}) {
  if (l.cancelled) return const [];
  if (l.state == ServiceState.served && !manager) return const [];
  return [
    for (final s in ServiceState.values)
      if (s != l.state) s,
  ];
}

/// The one button to show first: the next step in service. A delivered order has none (a manager can still undo it from the menu).
ServiceState? primaryMove(OrderLine l, {required bool manager}) {
  final next = l.state.next;
  if (next == null || l.cancelled) return null;
  return moveTargets(l, manager: manager).contains(next) ? next : null;
}

/// Arguments of `desk_set_service_status`.
Map<String, dynamic> moveParams(String lineId, ServiceState to) => {
  'p_line': lineId,
  'p_status': to.value,
};

// ---------------------------------------------------------------------------
// Waiting
// ---------------------------------------------------------------------------

/// How long something has been waiting: "just now", "5 min", "1 h 20 min", "3 days".
String waitedLabel(DateTime since, DateTime now) {
  final d = now.difference(since);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min';
  if (d.inHours < 24) {
    final m = d.inMinutes % 60;
    return m == 0 ? '${d.inHours} h' : '${d.inHours} h $m min';
  }
  final days = d.inDays;
  return '$days ${days == 1 ? 'day' : 'days'}';
}

// ---------------------------------------------------------------------------
// A table's money
// ---------------------------------------------------------------------------

/// Where a recorded payment stands. A photo alone never verifies a payment; "pending" reads "Recorded - verification pending".
enum Verification {
  pending('pending', 'Recorded - verification pending'),
  verified('verified', 'Verified'),
  customerConfirmed('customer_confirmed', 'Confirmed by the guest'),
  disputed('disputed', 'Disputed by the guest');

  const Verification(this.value, this.label);

  final String value;
  final String label;

  static Verification? fromDb(Object? v) {
    for (final s in values) {
      if (s.value == v) return s;
    }
    return null;
  }
}

class PaymentEntry {
  const PaymentEntry({
    required this.id,
    required this.billedCents,
    required this.paidCents,
    required this.method,
    required this.posReference,
    required this.receiptPath,
    required this.missingReceiptReason,
    required this.payerName,
    required this.recordedAt,
    required this.recordedByMe,
    required this.verification,
    required this.verifiedNote,
    required this.tipCents,
  });

  final String id;
  final int billedCents;
  final int paidCents;

  /// "cash", "debit", "credit" or "split", as stored.
  final String method;
  final String? posReference;
  final String? receiptPath;
  final String? missingReceiptReason;
  final String? payerName;
  final DateTime recordedAt;
  final bool recordedByMe;
  final Verification verification;
  final String? verifiedNote;
  final int tipCents;

  String get methodLabel => payMethodFromDb(method)?.label ?? method;
}

class BookingMoney {
  const BookingMoney({
    required this.level,
    required this.confirmationCode,
    required this.customerName,
    required this.tableName,
    required this.guestCount,
    required this.currency,
    required this.status,
    required this.totalCents,
    required this.paidCents,
    required this.balanceDueCents,
    required this.closedOut,
    required this.closeoutRequested,
    required this.payments,
  });

  /// 'manager', 'server' or 'verifier': how the database says this person stands towards the table.
  final String level;
  final String? confirmationCode;
  final String customerName;
  final String tableName;
  final int guestCount;
  final String currency;
  final String status;
  final int totalCents;
  final int paidCents;
  final int balanceDueCents;
  final bool closedOut;
  final bool closeoutRequested;
  final List<PaymentEntry> payments;

  bool get isManager => level == 'manager';

  /// A manager or the table's server may record a payment on a confirmed table that has not been closed out.
  bool get canRecord =>
      (level == 'manager' || level == 'server') &&
      status == 'paid' &&
      !closedOut;
}

/// The `desk_booking_money` answer. Null when it is not an object with a level (so the screen says it could not be read rather than
/// showing a table with no money).
BookingMoney? parseBookingMoney(dynamic data) {
  if (data is! Map) return null;
  final r = Map<String, dynamic>.from(data);
  final level = r['level'];
  if (level is! String || level.isEmpty) return null;
  final payments = <PaymentEntry>[];
  final raw = r['payments'];
  if (raw is List) {
    for (final p in raw) {
      if (p is! Map) continue;
      final id = p['id'];
      final at = _time(p['recorded_at']);
      final v = Verification.fromDb(p['verification']);
      if (id is! String || id.isEmpty || at == null || v == null) continue;
      payments.add(
        PaymentEntry(
          id: id,
          billedCents: _int(p['billed_amount_cents']),
          paidCents: _int(p['amount_paid_cents']),
          method: _text(p['payment_method']) ?? '',
          posReference: _text(p['pos_reference']),
          receiptPath: _text(p['receipt_photo_path']),
          missingReceiptReason: _text(p['missing_receipt_reason']),
          payerName: _text(p['payer_name']),
          recordedAt: at,
          recordedByMe: p['recorded_by_me'] == true,
          verification: v,
          verifiedNote: _text(p['manager_verified_note']),
          tipCents: _int(p['gratuity_cents']),
        ),
      );
    }
  }
  return BookingMoney(
    level: level,
    confirmationCode: _text(r['confirmation_code']),
    customerName: _text(r['customer_name']) ?? '',
    tableName: _text(r['table_name']) ?? '',
    guestCount: _int(r['guest_count']),
    currency: _text(r['currency']) ?? 'cad',
    status: _text(r['status']) ?? '',
    totalCents: _int(r['amount_total_cents']),
    paidCents: _int(r['amount_paid_cents']),
    balanceDueCents: _int(r['balance_due_cents']),
    closedOut: r['closed_out'] == true,
    closeoutRequested: r['closeout_requested'] == true,
    payments: payments,
  );
}

// ---------------------------------------------------------------------------
// The overlay on a server's tables, and "next action"
// ---------------------------------------------------------------------------

class TableStatus {
  const TableStatus({
    required this.bookingId,
    required this.balanceDueCents,
    required this.itemsOpen,
    required this.itemsDelivered,
    required this.paymentsRecorded,
    required this.paymentsUnchecked,
    required this.closedOut,
    required this.closeoutRequested,
  });

  final String bookingId;
  final int balanceDueCents;
  final int itemsOpen;
  final int itemsDelivered;
  final int paymentsRecorded;
  final int paymentsUnchecked;
  final bool closedOut;
  final bool closeoutRequested;
}

/// One `desk_table_status` row.
TableStatus? parseTableStatus(Map<String, dynamic> r) {
  final id = r['booking_id'];
  if (id is! String || id.isEmpty) return null;
  return TableStatus(
    bookingId: id,
    balanceDueCents: _int(r['balance_due_cents']),
    itemsOpen: _int(r['items_open']),
    itemsDelivered: _int(r['items_delivered']),
    paymentsRecorded: _int(r['payments_recorded']),
    paymentsUnchecked: _int(r['payments_unchecked']),
    closedOut: r['closed_out'] == true,
    closeoutRequested: r['closeout_requested'] == true,
  );
}

/// What the server should do about a table next, in one line (brief section 13: "table cards show table, lead guest and next action").
/// Closed out first; guests who have not arrived next; then what is still to deliver, then money owed, then a payment waiting to be
/// checked. Null when the status could not be loaded: no line is better than a wrong one.
String? nextAction(AssignedTable table, TableStatus? s) {
  if (s == null) return null;
  if (s.closedOut) return 'Closed out';
  if (!table.arrived) return 'Waiting for the guests';
  if (s.itemsOpen > 0) {
    return '${s.itemsOpen} ${s.itemsOpen == 1 ? 'item' : 'items'} to deliver';
  }
  if (s.balanceDueCents > 0) {
    return 'Take payment: ${formatDollars(s.balanceDueCents)}';
  }
  if (s.paymentsUnchecked > 0) {
    return 'Payment recorded - waiting to be checked';
  }
  return 'Nothing to do';
}

// ---------------------------------------------------------------------------
// Recording a payment
// ---------------------------------------------------------------------------

enum PayMethod {
  cash('cash', 'Cash'),
  debit('debit', 'Debit'),
  credit('credit', 'Credit'),
  split('split', 'Split');

  const PayMethod(this.value, this.label);

  final String value;
  final String label;
}

PayMethod? payMethodFromDb(Object? v) {
  for (final m in PayMethod.values) {
    if (m.value == v) return m;
  }
  return null;
}

/// The most money the database accepts in any one field, in cents ($100,000).
const int maxPaymentCents = 10000000;
const int maxReceiptNumberLength = 80;
const int maxPayerNameLength = 120;
const int maxReasonLength = 300;
const int maxSplitBreakdownLength = 2000;

/// One part of a split payment.
class SplitPart {
  const SplitPart(this.method, this.cents);

  /// Cash, debit or credit; never split.
  final PayMethod method;
  final int cents;

  Map<String, dynamic> toJson() => {'method': method.value, 'cents': cents};
}

/// What the person typed on the payment form. Money is text, parsed here by its digits (never floating point).
class PaymentInput {
  const PaymentInput({
    this.billed = '',
    this.collected = '',
    this.method,
    this.split = const [],
    this.posReference = '',
    this.payerName = '',
    this.bottles = '',
    this.discount = '',
    this.tax = '',
    this.tip = '',
    this.hasReceiptPhoto = false,
    this.receiptReadable = false,
    this.noReceiptReason = '',
    this.noReceipt = false,
  });

  final String billed;
  final String collected;
  final PayMethod? method;
  final List<SplitPart> split;
  final String posReference;
  final String payerName;
  final String bottles;
  final String discount;
  final String tax;
  final String tip;

  /// A receipt photo has been taken and kept.
  final bool hasReceiptPhoto;

  /// The person confirmed the total and the date can be read on it.
  final bool receiptReadable;

  /// A manager recording without a receipt, and why.
  final bool noReceipt;
  final String noReceiptReason;
}

/// The part of a payment form that is wrong, by field, in plain words. Empty when it can be sent. Mirrors desk_record_payment: the
/// database still checks everything, so this only spares a round trip and says it kindly.
Map<String, String> paymentProblems(PaymentInput f, {required bool manager}) {
  final out = <String, String>{};

  int? money(
    String key,
    String text, {
    required bool required,
    required String name,
  }) {
    if (text.trim().isEmpty) {
      if (required) out[key] = 'Enter the $name.';
      return null;
    }
    final c = parseMoney(text);
    if (c == null) {
      out[key] = 'The $name must be an amount like 120.50.';
      return null;
    }
    if (c > maxPaymentCents) {
      out[key] = 'The $name is too large.';
      return null;
    }
    return c;
  }

  money('billed', f.billed, required: true, name: 'bill total');
  final collected = money(
    'collected',
    f.collected,
    required: true,
    name: 'amount collected',
  );
  if (collected != null && collected == 0) {
    out['collected'] = 'Enter the amount collected.';
  }
  money('bottles', f.bottles, required: false, name: 'bottle subtotal');
  money('discount', f.discount, required: false, name: 'discount');
  money('tax', f.tax, required: false, name: 'tax');
  money('tip', f.tip, required: false, name: 'tip');

  if (f.method == null) out['method'] = 'Choose how it was paid.';
  if (f.method == PayMethod.split) {
    if (f.split.length < 2) {
      out['split'] = 'Add the parts of the split.';
    } else if (f.split.any((p) => p.cents <= 0)) {
      out['split'] = 'Every part of a split needs an amount.';
    } else if (collected != null &&
        f.split.fold<int>(0, (s, p) => s + p.cents) != collected) {
      out['split'] =
          'The parts of the split must add up to the amount collected.';
    }
  }

  if (f.posReference.trim().length > maxReceiptNumberLength) {
    out['pos'] = 'The receipt number is too long.';
  }
  if (f.payerName.trim().length > maxPayerNameLength) {
    out['payer'] = "The payer's name is too long.";
  }

  if (f.noReceipt) {
    if (!manager) {
      out['receipt'] = 'A receipt photo is required.';
    } else if (f.noReceiptReason.trim().isEmpty) {
      out['receipt'] = 'Say why there is no receipt.';
    } else if (f.noReceiptReason.trim().length > maxReasonLength) {
      out['receipt'] =
          'Keep the reason to $maxReasonLength characters or fewer.';
    }
  } else if (!f.hasReceiptPhoto) {
    out['receipt'] = 'Take a photo of the receipt.';
  } else if (!f.receiptReadable) {
    out['receipt'] =
        'Check that the total and the date can be read on the photo.';
  }
  return out;
}

/// The arguments of `desk_record_payment` for a form that has no problems. A blank optional field is sent as none. The split is sent
/// only for a split payment. A manager's reason is sent only when there is no photo.
Map<String, dynamic> recordPaymentParams(
  String bookingId,
  PaymentInput f, {
  String? receiptPath,
  String? receiptHash,
  String? deviceId,
}) {
  int cents(String t) => t.trim().isEmpty ? 0 : parseMoney(t) ?? 0;
  String? none(String t) => t.trim().isEmpty ? null : t.trim();
  final isSplit = f.method == PayMethod.split;
  return {
    'p_booking': bookingId,
    'p_billed_amount_cents': cents(f.billed),
    'p_amount_paid_cents': cents(f.collected),
    'p_payment_method': f.method?.value,
    'p_split_breakdown': isSplit ? [for (final p in f.split) p.toJson()] : null,
    'p_pos_reference': none(f.posReference),
    'p_receipt_photo_path': receiptPath,
    'p_payer_name': none(f.payerName),
    'p_payer_email': null,
    'p_bottle_subtotal_cents': cents(f.bottles),
    'p_discount_cents': cents(f.discount),
    'p_tax_cents': cents(f.tax),
    'p_gratuity_cents': cents(f.tip),
    'p_receipt_photo_hash': receiptHash,
    'p_device_id': deviceId,
    'p_missing_receipt_reason':
        receiptPath == null ? none(f.noReceiptReason) : null,
  };
}

/// What `desk_record_payment` answered.
class RecordedPayment {
  const RecordedPayment({
    required this.paymentId,
    required this.duplicate,
    required this.balanceDueCents,
  });

  final String paymentId;

  /// The same receipt (or the same entry a moment ago) was already recorded; nothing was written a second time.
  final bool duplicate;
  final int balanceDueCents;
}

RecordedPayment? parseRecordedPayment(dynamic data) {
  if (data is! Map || data['success'] != true) return null;
  final id = data['payment_id'];
  if (id is! String || id.isEmpty) return null;
  return RecordedPayment(
    paymentId: id,
    duplicate: data['duplicate'] == true,
    balanceDueCents: _int(data['balance_due_cents']),
  );
}

/// Where a receipt photo is filed: inside the booking's own folder, which is what ties it to the booking and decides who may open it.
String receiptStoragePath(String bookingId, String extension, String id) =>
    '$bookingId/$id.$extension';

// ---------------------------------------------------------------------------
// The checking queue
// ---------------------------------------------------------------------------

class PendingPayment {
  const PendingPayment({
    required this.paymentId,
    required this.bookingId,
    required this.confirmationCode,
    required this.customerName,
    required this.tableName,
    required this.method,
    required this.billedCents,
    required this.paidCents,
    required this.posReference,
    required this.receiptPath,
    required this.missingReceiptReason,
    required this.recordedAt,
    required this.recordedByName,
    required this.recordedByMe,
    required this.disputed,
    required this.disputeReason,
  });

  final String paymentId;
  final String bookingId;
  final String? confirmationCode;
  final String customerName;
  final String tableName;
  final String method;
  final int billedCents;
  final int paidCents;
  final String? posReference;
  final String? receiptPath;
  final String? missingReceiptReason;
  final DateTime recordedAt;
  final String? recordedByName;
  final bool recordedByMe;
  final bool disputed;
  final String? disputeReason;

  String get methodLabel => payMethodFromDb(method)?.label ?? method;

  /// The database refuses to verify your own entry, one the guest disputed, or one already verified (it is not listed then).
  bool get canVerify => !recordedByMe && !disputed;

  /// Why there is no Verify button, or null when there is one.
  String? get cannotVerifyBecause {
    if (disputed) {
      return 'The guest disputed this payment. A manager has to settle it.';
    }
    if (recordedByMe) {
      return 'You recorded this payment, so someone else has to verify it.';
    }
    return null;
  }
}

/// One `desk_pending_verifications` row.
PendingPayment? parsePendingPayment(Map<String, dynamic> r) {
  final id = r['payment_id'];
  final booking = r['booking_id'];
  final at = _time(r['recorded_at']);
  if (id is! String ||
      id.isEmpty ||
      booking is! String ||
      booking.isEmpty ||
      at == null) {
    return null;
  }
  return PendingPayment(
    paymentId: id,
    bookingId: booking,
    confirmationCode: _text(r['confirmation_code']),
    customerName: _text(r['customer_name']) ?? '',
    tableName: _text(r['table_name']) ?? '',
    method: _text(r['payment_method']) ?? '',
    billedCents: _int(r['billed_amount_cents']),
    paidCents: _int(r['amount_paid_cents']),
    posReference: _text(r['pos_reference']),
    receiptPath: _text(r['receipt_photo_path']),
    missingReceiptReason: _text(r['missing_receipt_reason']),
    recordedAt: at,
    recordedByName: _text(r['recorded_by_name']),
    recordedByMe: r['recorded_by_me'] == true,
    disputed: r['customer_confirmation_status'] == 'disputed',
    disputeReason: _text(r['dispute_reason']),
  );
}

const int verifyNoteLimit = 300;

/// A sentence about what is wrong with a verification note, or null. A note is optional.
String? validateVerifyNote(String text) =>
    text.trim().length > verifyNoteLimit
        ? 'Keep the note to $verifyNoteLimit characters or fewer.'
        : null;

Map<String, dynamic> verifyParams(String paymentId, String? note) => {
  'p_payment': paymentId,
  'p_note': (note == null || note.trim().isEmpty) ? null : note.trim(),
};

// ---------------------------------------------------------------------------
// Tonight
// ---------------------------------------------------------------------------

class TonightCounts {
  const TonightCounts({
    required this.tables,
    required this.guests,
    required this.arrived,
    required this.withoutServer,
    required this.withBalance,
    required this.balanceDueCents,
    required this.ordersNew,
    required this.ordersInProgress,
    required this.ordersDelivered,
    required this.paymentsToCheck,
    required this.paymentsDisputed,
    required this.closeoutsRequested,
    required this.requestsOpen,
  });

  // About the night:
  final int tables;
  final int guests;
  final int arrived;
  final int withoutServer;
  final int withBalance;
  final int balanceDueCents;
  final int ordersNew;
  final int ordersInProgress;
  final int ordersDelivered;

  // Club-wide (their lists are not tied to a night):
  final int paymentsToCheck;
  final int paymentsDisputed;
  final int closeoutsRequested;
  final int requestsOpen;

  /// The length of the checking queue: unchecked payments plus disputed ones.
  int get paymentQueue => paymentsToCheck + paymentsDisputed;
}

/// The one `desk_tonight` row, or null when the answer has no row.
TonightCounts? parseTonight(Map<String, dynamic> r) {
  if (!r.containsKey('tables')) return null;
  return TonightCounts(
    tables: _int(r['tables']),
    guests: _int(r['guests']),
    arrived: _int(r['arrived']),
    withoutServer: _int(r['without_server']),
    withBalance: _int(r['with_balance']),
    balanceDueCents: _int(r['balance_due_cents']),
    ordersNew: _int(r['orders_new']),
    ordersInProgress: _int(r['orders_in_progress']),
    ordersDelivered: _int(r['orders_delivered']),
    paymentsToCheck: _int(r['payments_to_check']),
    paymentsDisputed: _int(r['payments_disputed']),
    closeoutsRequested: _int(r['closeouts_requested']),
    requestsOpen: _int(r['requests_open']),
  );
}

// ---------------------------------------------------------------------------
// Wording for a failed load
// ---------------------------------------------------------------------------

/// The same wording as the rest of the server desk, for the things loaded here: "Orders are not set up on this server yet."
String tableServiceLoadMessage({
  required bool unavailable,
  required bool accessEnded,
  required String what,
}) {
  String capital(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
  if (unavailable) return '${capital(what)} are not set up on this server yet.';
  if (accessEnded) return 'Your access has ended, or you are signed out.';
  return '${capital(what)} could not be loaded. Check your connection and try again.';
}
