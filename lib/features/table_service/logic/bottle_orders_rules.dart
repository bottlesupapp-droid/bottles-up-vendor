// Adding bottles to a table and handing over part of an order (developer brief 15 Oct, section 16; acceptance steps 10 and 11). Pure Dart, tested without a screen.
// The database decides who may do either and whether now is the time (website: 20261020150000_add_bottles_checks.sql and 20261020160000_partial_delivery.sql, and the
// edge function add-table-booking-bottles for pricing, stock and the table's totals); this file knows the shapes of the answers, which buttons make sense, and the
// plain sentences for a failure, so nothing is offered that would be refused and nothing technical is ever shown.

import '../../owner/logic/setup_forms.dart' show formatDollars;
import 'table_service_rules.dart';

int? _intOrNull(Object? v) => v is int ? v : (v is num && v == v.roundToDouble() ? v.toInt() : null);
String? _text(Object? v) => v is String && v.trim().isNotEmpty ? v.trim() : null;

// ---------------------------------------------------------------------------
// The menu and the basket
// ---------------------------------------------------------------------------

/// The most of one bottle that can be put in the basket at once: a sanity limit of the screen (the database has none), not a business rule.
const int maxPerBottle = 99;

class MenuBottle {
  const MenuBottle({required this.id, required this.name, required this.priceCents, this.size, this.category, this.leftCount});

  final String id;
  final String name;
  final String? size;
  final String? category;
  final int priceCents;

  /// How many are left by the club's own count, or null when the club does not count this bottle.
  final int? leftCount;

  bool get soldOutByCount => leftCount != null && leftCount! <= 0;

  /// "Patron 750ml".
  String get title => size == null ? name : '$name $size';

  /// The most that can be chosen.
  int get most => leftCount == null ? maxPerBottle : (leftCount! < maxPerBottle ? (leftCount! < 0 ? 0 : leftCount!) : maxPerBottle);
}

/// One `desk_bottle_menu` row. A row without an id, a name or a price is dropped rather than guessed at.
MenuBottle? parseMenuBottle(Map<String, dynamic> r) {
  final id = _text(r['bottle_id']);
  final name = _text(r['name']);
  final price = _intOrNull(r['price_cents']);
  if (id == null || name == null || price == null || price < 0) return null;
  return MenuBottle(id: id, name: name, size: _text(r['size']), category: _text(r['category']), priceCents: price, leftCount: _intOrNull(r['left_count']));
}

/// bottle id -> how many. Only positive amounts are kept.
typedef Basket = Map<String, int>;

int basketCount(Basket b) => b.values.fold(0, (a, n) => a + (n > 0 ? n : 0));

/// What the chosen bottles cost before tax and fees (the table's own total, with tax and fees, is worked out by the website).
int basketSubtotalCents(List<MenuBottle> menu, Basket b) {
  var total = 0;
  for (final m in menu) {
    final n = b[m.id] ?? 0;
    if (n > 0) total += m.priceCents * n;
  }
  return total;
}

/// The same basket with [id] set to [n] (clamped to what the menu allows), or without it at 0.
Basket withQuantity(List<MenuBottle> menu, Basket b, String id, int n) {
  final m = menu.where((x) => x.id == id).firstOrNull;
  final next = Map<String, int>.of(b);
  final limit = m?.most ?? 0;
  final v = n < 0 ? 0 : (n > limit ? limit : n);
  if (v == 0) {
    next.remove(id);
  } else {
    next[id] = v;
  }
  return next;
}

/// The basket without what the menu no longer offers or no longer has enough of (after the menu was read again).
Basket pruneBasket(List<MenuBottle> menu, Basket b) {
  final out = <String, int>{};
  for (final m in menu) {
    final n = b[m.id] ?? 0;
    if (n <= 0) continue;
    final v = n > m.most ? m.most : n;
    if (v > 0) out[m.id] = v;
  }
  return out;
}

/// What is wrong with the basket, in plain words, or null when it can be sent.
String? basketProblem(List<MenuBottle> menu, Basket b) {
  if (basketCount(b) < 1) return 'Choose at least one bottle.';
  for (final e in b.entries) {
    if (e.value < 1) continue;
    final m = menu.where((x) => x.id == e.key).firstOrNull;
    if (m == null) return 'One of the chosen bottles is no longer on the menu.';
    if (m.leftCount != null && e.value > m.leftCount!) return 'Only ${m.leftCount} of ${m.title} ${m.leftCount == 1 ? 'is' : 'are'} left.';
  }
  return null;
}

/// The `bottles` of the request, in the menu's order, only what was chosen.
List<Map<String, dynamic>> basketRequest(List<MenuBottle> menu, Basket b) => [
      for (final m in menu)
        if ((b[m.id] ?? 0) > 0) {'bottle_id': m.id, 'quantity': b[m.id]},
    ];

/// The body of the call to the add-bottles function.
Map<String, dynamic> addBottlesBody(String bookingId, List<MenuBottle> menu, Basket b) => {'booking_id': bookingId, 'bottles': basketRequest(menu, b)};

/// A capital letter at the start and a full stop at the end ("this night has been closed" becomes "This night has been closed.").
String _sentence(String message) {
  final t = message.trim();
  final s = t[0].toUpperCase() + t.substring(1);
  return RegExp(r'[.!?]$').hasMatch(s) ? s : '$s.';
}

/// What a failed call to the add-bottles function says to the person. [status] is the HTTP status when the function answered, null when the call never got an
/// answer (no connection, a timeout). [message] is the function's own `error` sentence when there is one.
///
/// A call that never got an answer may or may not have added the bottles, so the sentence says to look at the table's orders before trying again: adding twice
/// would charge the table twice.
String addBottlesFailure({int? status, String? message}) {
  final m = message?.trim() ?? '';
  switch (status) {
    case null:
      return 'We could not tell whether the bottles were added. Look at the table\'s orders before trying again, so nothing is added twice.';
    case 401:
      return 'Your sign-in has ended. Sign in again, then check the table\'s orders before adding bottles.';
    case 403:
      return "You don't have access to add bottles to this table.";
    case 404:
      return 'This booking could not be found.';
    case 400:
    case 409:
      if (m.isNotEmpty) return _sentence(m);
      return 'The bottles could not be added.';
  }
  return 'The bottles could not be added. Look at the table\'s orders before trying again, so nothing is added twice.';
}

/// Whether the bottles may have been added although the call failed: no answer at all, or the server failed (5xx) after it may have started. A refusal (400, 401, 403,
/// 404, 409) happened before anything was added.
bool addBottlesOutcomeUnknown(int? status) => status == null || status >= 500;

/// The function refused for a reason that the menu on the screen may be out of date for (a bottle gone, not enough left): read the menu again.
bool refusalMeansStaleMenu(String message) {
  final t = message.toLowerCase();
  return t.contains('no longer available') || t.contains('not enough') || t.contains('left in stock');
}

// ---------------------------------------------------------------------------
// Partial delivery
// ---------------------------------------------------------------------------

/// How many of a line are still to hand over.
int remainingToDeliver(OrderLine l) {
  final left = l.quantity - l.deliveredQuantity;
  return left < 0 ? 0 : left;
}

/// Whether to offer "Deliver some" on this line: only where the database has the delivered count, the line is Ready or On the way, not cancelled, and there is
/// more than one bottle still to hand over (handing over the last one is the ordinary Delivered button).
bool canDeliverPart(OrderLine l) =>
    l.deliveryKnown &&
    !l.cancelled &&
    (l.state == ServiceState.ready || l.state == ServiceState.pickedUp) &&
    l.payment != LinePayment.pendingPayment &&
    remainingToDeliver(l) >= 2;

/// "2 of 5 delivered", shown while a line is part way; null when nothing was handed over yet or the line is done.
String? deliveredLabel(OrderLine l) {
  if (!l.deliveryKnown || l.cancelled || l.delivered || l.deliveredQuantity <= 0) return null;
  return '${l.deliveredQuantity} of ${l.quantity} delivered';
}

/// The arguments of `desk_deliver_part`. [already] is how many the person saw as delivered: the database refuses if it moved since.
Map<String, dynamic> deliverPartParams(String lineId, int quantity, int already) => {'p_line': lineId, 'p_quantity': quantity, 'p_already': already};

class DeliveryResult {
  const DeliveryResult({required this.delivered, required this.quantity, required this.state});

  final int delivered;
  final int quantity;
  final ServiceState state;

  bool get complete => delivered >= quantity;
}

/// The `desk_deliver_part` answer. Null when it is not what was expected (the screen then says to look at the table before trying again).
DeliveryResult? parseDeliveryResult(dynamic data) {
  if (data is! Map) return null;
  final delivered = _intOrNull(data['delivered']);
  final quantity = _intOrNull(data['quantity']);
  final state = ServiceState.fromDb(data['service_status']);
  if (delivered == null || quantity == null || state == null || quantity < 1 || delivered < 0) return null;
  return DeliveryResult(delivered: delivered, quantity: quantity, state: state);
}

/// What to say after a hand-over: "2 of 5 delivered." or "All 5 delivered."
String deliveryOutcomeMessage(OrderLine l, DeliveryResult r) =>
    r.complete ? 'All ${r.quantity} of ${l.bottleName} delivered.' : '${r.delivered} of ${r.quantity} ${l.bottleName} delivered.';

/// A sentence for the confirmation: "Added 3 bottles. They are due at the club: $540.00 before tax."
String addedMessage(int count, int subtotalCents) =>
    'Added $count ${count == 1 ? 'bottle' : 'bottles'}. ${count == 1 ? 'It is' : 'They are'} due at the club (${formatDollars(subtotalCents)} before tax).';
